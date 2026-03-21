// Common rarity shader — subtle silver/grey pulsing border glow
extern float time;
extern vec2 cardSize;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Distance from edge (0 at edge, 1 at center)
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // Pulsing border glow
    float pulse = 0.5 + 0.5 * sin(time * 2.0);
    float glowWidth = 0.06 + 0.02 * pulse;
    float glow = smoothstep(glowWidth, 0.0, edgeDist);

    // Silver color
    vec3 glowColor = vec3(0.75, 0.78, 0.82);
    float glowIntensity = glow * (0.4 + 0.3 * pulse);

    vec3 finalColor = texColor.rgb + glowColor * glowIntensity;
    return vec4(finalColor, texColor.a) * color;
}
