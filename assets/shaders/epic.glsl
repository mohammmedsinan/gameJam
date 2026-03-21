// Epic rarity shader — purple lightning arcs across the card frame
extern float time;
extern vec2 cardSize;

// Pseudo-random hash
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM for lightning
float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        val += amp * noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return val;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Edge distance
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // Lightning arcs along frame
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    vec2 noiseUV = vec2(angle * 2.0, time * 1.5);
    float lightning = fbm(noiseUV * 3.0);
    lightning = pow(lightning, 2.0);

    // Flickering intensity
    float flicker = 0.7 + 0.3 * sin(time * 8.0 + hash(vec2(floor(time * 4.0))) * 6.28);

    float glowWidth = 0.09;
    float glow = smoothstep(glowWidth, 0.0, edgeDist);

    // Electric arc lines
    float arcWidth = 0.04;
    float arc = smoothstep(arcWidth, 0.0, edgeDist) * lightning * flicker;

    // Purple tones
    vec3 glowColor = mix(
        vec3(0.50, 0.10, 0.85),
        vec3(0.75, 0.30, 1.00),
        lightning
    );
    vec3 arcColor = vec3(0.85, 0.60, 1.00);

    float glowIntensity = glow * 0.5;
    float innerGlow = smoothstep(0.22, 0.06, edgeDist) * 0.12;

    vec3 finalColor = texColor.rgb
        + glowColor * (glowIntensity + innerGlow)
        + arcColor * arc * 0.8;

    return vec4(finalColor, texColor.a) * color;
}
