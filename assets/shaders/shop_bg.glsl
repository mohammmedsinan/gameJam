// Balatro-style crosshatch/diamond pattern background shader
extern float time;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 texColor = Texel(tex, uv);

    // Diamond crosshatch pattern
    vec2 pixel = px;
    float scale = 12.0;
    float lineW = 0.12;

    // Two diagonal line sets
    float d1 = mod(pixel.x + pixel.y, scale) / scale;
    float d2 = mod(pixel.x - pixel.y, scale) / scale;

    float line1 = smoothstep(lineW, lineW + 0.02, abs(d1 - 0.5));
    float line2 = smoothstep(lineW, lineW + 0.02, abs(d2 - 0.5));

    float pattern = line1 * line2;

    // Subtle animated shimmer
    float shimmer = 0.02 * sin(time * 0.5 + pixel.x * 0.01 + pixel.y * 0.01);

    // Dark base with slightly visible diamond grid
    vec3 baseColor = vec3(0.10, 0.10, 0.12);
    vec3 gridColor = vec3(0.16, 0.16, 0.19);

    vec3 finalColor = mix(gridColor, baseColor, pattern) + shimmer;

    return vec4(finalColor, 1.0) * color;
}
