// Uncommon rarity shader — green shimmer along edges
extern float time;
extern vec2 cardSize;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Edge distance
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // Travelling shimmer wave along the perimeter
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float wave = 0.5 + 0.5 * sin(angle * 3.0 + time * 3.0);

    float glowWidth = 0.07;
    float glow = smoothstep(glowWidth, 0.0, edgeDist);

    // Green tones
    vec3 glowColor = mix(
        vec3(0.15, 0.65, 0.30),
        vec3(0.30, 0.90, 0.50),
        wave
    );
    float glowIntensity = glow * (0.5 + 0.3 * wave);

    vec3 finalColor = texColor.rgb + glowColor * glowIntensity;
    return vec4(finalColor, texColor.a) * color;
}
