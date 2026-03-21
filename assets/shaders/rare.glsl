// Rare rarity shader — animated blue energy swirl around the border
extern float time;
extern vec2 cardSize;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Edge distance
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // Swirling energy pattern
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float dist = length(uv - vec2(0.5));

    float swirl1 = sin(angle * 4.0 + time * 4.0 + dist * 10.0);
    float swirl2 = sin(angle * 6.0 - time * 3.0 + dist * 8.0);
    float swirl = 0.5 + 0.25 * swirl1 + 0.25 * swirl2;

    float glowWidth = 0.08;
    float glow = smoothstep(glowWidth, 0.0, edgeDist);

    // Inner glow — fainter, reaching further
    float innerGlow = smoothstep(0.20, 0.06, edgeDist) * 0.15;

    // Blue tones
    vec3 glowColor = mix(
        vec3(0.10, 0.40, 0.95),
        vec3(0.30, 0.70, 1.00),
        swirl
    );

    float glowIntensity = glow * (0.55 + 0.35 * swirl);

    vec3 finalColor = texColor.rgb + glowColor * (glowIntensity + innerGlow);
    return vec4(finalColor, texColor.a) * color;
}
