local love = require("love")

local DungeonShader = {
    _shader = nil,
    _time = 0
}

local shaderCode = [[
extern number time;

// Simple 2D hash
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

// Fractal Brownian Motion for swirling fog
float fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for(int i=0; i<4; i++) {
        f += w * noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 p = screen_coords.xy / love_ScreenSize.xy;
    p.y = 1.0 - p.y;

    // Deep dark stone base color
    vec3 col = vec3(0.02, 0.02, 0.03);

    // Slowly drifting fog
    vec2 fog_uv = p * 4.0;
    fog_uv.x += time * 0.05;
    fog_uv.y += sin(time * 0.02);
    float fog = fbm(fog_uv) * 0.5 + fbm(fog_uv * 2.0 - time * 0.08) * 0.5;
    col += vec3(0.05, 0.06, 0.08) * fog;

    // Flickering torchlight in the center
    float flicker = noise(vec2(time * 8.0, 0.0)) * 0.15 + 0.85;
    vec2 light_pos = vec2(0.5, 0.4);

    // Aspect ratio correction for circular light
    vec2 p_ratio = p;
    p_ratio.x *= love_ScreenSize.x / love_ScreenSize.y;
    light_pos.x *= love_ScreenSize.x / love_ScreenSize.y;

    float dist = distance(p_ratio, light_pos);
    float light = smoothstep(1.0, 0.0, dist) * flicker;

    // Warm orange/yellow torch hue
    col += vec3(0.6, 0.25, 0.05) * light * 0.9;

    // Heavy vignette to enforce dark, moody borders
    float vig = smoothstep(1.1, 0.2, distance(p, vec2(0.5)));
    col *= vig;

    return vec4(col, 1.0) * color;
}
]]

function DungeonShader:get()
    if not self._shader then
        self._shader = love.graphics.newShader(shaderCode)
    end
    return self._shader
end

function DungeonShader:update(dt)
    self._time = self._time + dt
    local s = self:get()
    if s then s:send("time", self._time) end
end

function DungeonShader:draw()
    local s = self:get()
    if s then
        love.graphics.setShader(s)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        love.graphics.setShader()
    else
        love.graphics.setColor(0.02, 0.02, 0.03, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function DungeonShader:getTime()
    return self._time
end

return DungeonShader
