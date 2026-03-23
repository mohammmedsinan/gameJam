// character.glsl — Shared character shader for idle/attack/damage states
extern float time;
extern float state;        // 0=idle, 1=attack, 2=damage (interpolated)
extern vec3  baseColor;    // character energy color
extern float intensity;    // overall effect intensity 0–1
extern float damageFlash;  // damage red overlay 0–1
extern float isBoss;       // 1.0 for boss entities

// Simple hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// FBM for energy patterns
float fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for(int i = 0; i < 3; i++) {
        f += w * noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 px) {
    // ── Base character fill ──
    // Dark interior with subtle energy
    vec3 darkBase = vec3(0.08, 0.08, 0.12);

    // ── Edge glow ──
    float borderX = min(uv.x, 1.0 - uv.x);
    float borderY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(borderX, borderY);

    // Breathing pulse for idle
    float breathe = 0.5 + 0.5 * sin(time * 2.0);

    // State blending: idle → attack → damage
    float idleAmt  = max(0.0, 1.0 - abs(state));
    float atkAmt   = max(0.0, 1.0 - abs(state - 1.0));
    float dmgAmt   = max(0.0, 1.0 - abs(state - 2.0));

    // ── Border glow width and intensity by state ──
    float glowWidth = 0.08 + 0.03 * breathe;
    float glowPower = 0.5 + 0.3 * breathe;   // idle glow

    // Attack: wider, brighter glow
    glowWidth += atkAmt * 0.06;
    glowPower += atkAmt * 0.6;

    // Damage: thin but intense red
    glowWidth += dmgAmt * 0.02;

    float glow = smoothstep(glowWidth, 0.0, edgeDist);

    // ── Inner energy pattern ──
    vec2 energyUV = uv * 4.0;
    energyUV.x += time * 0.3;
    energyUV.y += sin(time * 0.5) * 0.5;
    float energy = fbm(energyUV) * 0.3;
    energy += fbm(energyUV * 1.5 - time * 0.2) * 0.2;

    // Energy is more visible during attack
    energy *= (0.4 + atkAmt * 0.8 + idleAmt * 0.3);

    // ── Compose color ──
    vec3 energyColor = baseColor;

    // Attack: shift to brighter, more saturated
    energyColor = mix(energyColor, baseColor * 1.6 + vec3(0.2), atkAmt * 0.5);

    // Glow ring
    vec3 glowColor = energyColor * glowPower;

    // Core pattern
    vec3 coreColor = darkBase + energyColor * energy * intensity;

    // Combine: core + edge glow
    vec3 finalColor = mix(coreColor, glowColor, glow * intensity);

    // ── Damage flash overlay ──
    vec3 damageColor = vec3(1.0, 0.15, 0.1);
    finalColor = mix(finalColor, damageColor, damageFlash * 0.8);

    // ── Boss aura (extra outer shimmer) ──
    if (isBoss > 0.5) {
        float bossGlow = smoothstep(0.15, 0.0, edgeDist);
        float bossPulse = 0.5 + 0.5 * sin(time * 3.0 + uv.x * 6.28);
        finalColor += vec3(0.85, 0.3, 1.0) * bossGlow * bossPulse * 0.15;
    }

    // ── Scanline-like subtle effect (fits CRT theme) ──
    float scanline = 0.95 + 0.05 * sin(px.y * 3.0 + time * 2.0);
    finalColor *= scanline;

    return vec4(finalColor, 1.0) * color;
}
