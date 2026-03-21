// Legendary rarity shader — fiery gold holographic rainbow sweep with particles
extern float time;
extern vec2 cardSize;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Edge distance
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // ── Holographic rainbow sweep ──
    float sweep = fract(uv.x * 0.5 + uv.y * 0.3 + time * 0.4);
    vec3 rainbow = hsv2rgb(vec3(sweep, 0.6, 1.0));

    // ── Fire base (gold/orange) ──
    float fireNoise = noise(vec2(uv.x * 4.0 + time * 2.0, uv.y * 6.0 - time * 3.0));
    vec3 fireColor = mix(
        vec3(1.0, 0.65, 0.0),   // orange
        vec3(1.0, 0.85, 0.20),  // gold
        fireNoise
    );

    // Blend fire + rainbow
    vec3 glowColor = mix(fireColor, rainbow, 0.35);

    // ── Border glow ──
    float glowWidth = 0.10;
    float glow = smoothstep(glowWidth, 0.0, edgeDist);
    float innerGlow = smoothstep(0.25, 0.06, edgeDist) * 0.18;

    // Pulsing intensity
    float pulse = 0.6 + 0.4 * sin(time * 2.5);
    float glowIntensity = glow * (0.6 + 0.3 * pulse);

    // ── Sparkle particles ──
    vec2 sparkleGrid = floor(uv * 20.0);
    float sparkleRand = hash(sparkleGrid);
    float sparkleTime = fract(sparkleRand * 10.0 + time * (1.0 + sparkleRand));
    float sparkle = step(0.92, sparkleRand) * pow(1.0 - sparkleTime, 8.0);
    sparkle *= glow;

    vec3 finalColor = texColor.rgb
        + glowColor * (glowIntensity + innerGlow)
        + vec3(1.0, 0.95, 0.80) * sparkle * 1.5;

    return vec4(finalColor, texColor.a) * color;
}
