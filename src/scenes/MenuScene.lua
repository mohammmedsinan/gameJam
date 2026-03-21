local MenuScene = {}
MenuScene.__index = MenuScene

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Dark and moody dungeon shader with fog and flickering torchlight
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

function MenuScene:load()
	self.time = 0
	self.shader = love.graphics.newShader(shaderCode)

	-- Font setup
	self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
	self.titleFont = love.graphics.setNewFont(54) or love.graphics.getFont()
end

function MenuScene:enter(prev)
	self.time = 0
	local w, h = love.graphics.getDimensions()

	if not self.font then
		self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
	end

	-- Dungeon-style buttons (Settings, Credits replacing Shop)
	self.buttons = {
		{ text = "ENTER DUNGEON", target = "game",     y = h * 0.4,       w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "SETTINGS",      target = "settings", y = h * 0.4 + 70,  w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "CREDITS",       target = "credits",  y = h * 0.4 + 140, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "FLEE (QUIT)",   target = "quit",     y = h * 0.4 + 210, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 }
	}

	love.graphics.setFont(self.font)
end

function MenuScene:update(dt)
	self.time = self.time + dt
	self.shader:send("time", self.time)

	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	if self.buttons then
		for i, btn in ipairs(self.buttons) do
			local bx = cx - btn.w / 2
			local by = btn.y
			btn.hover = (mx >= bx and mx <= bx + btn.w and my >= by and my <= by + btn.h)

			local targetScale = btn.hover and 1.05 or 1.0
			btn.scale = lerp(btn.scale, targetScale, dt * 10)
			btn.clickScale = lerp(btn.clickScale, 1.0, dt * 15)
		end
	end
end

function MenuScene:draw()
	love.graphics.push("all")
	if self.shader then
		love.graphics.setShader(self.shader)
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
	love.graphics.setShader()

	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	if self.titleFont then
		love.graphics.setFont(self.titleFont)
	end
	-- Deep shadow / drop shadow
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.printf("BROADCAST DUNGEON", 4, h * 0.15 + 4, w, "center")

	-- Flickering title text color simulating torchlight
	local flicker = (math.sin(self.time * 6) + math.sin(self.time * 11)) * 0.1 + 0.9
	love.graphics.setColor(0.9 * flicker, 0.8 * flicker, 0.6 * flicker, 1)
	love.graphics.printf("BROADCAST DUNGEON", 0, h * 0.15, w, "center")

	if self.font then
		love.graphics.setFont(self.font)
	end

	if self.buttons then
		for i, btn in ipairs(self.buttons) do
			local totalScale = btn.scale * btn.clickScale
			local bw = btn.w * totalScale
			local bh = btn.h * totalScale
			local bx = cx - bw / 2
			local by = btn.y + (btn.h - bh) / 2

			-- Ambient glow behind hovered button
			if btn.hover then
				love.graphics.setColor(0.8, 0.4, 0.1, 0.2)
				love.graphics.rectangle("fill", bx - 5, by - 5, bw + 10, bh + 10, 8, 8)
			end

			-- Button backgrounds (Dark stone appearance)
			if btn.hover then
				love.graphics.setColor(0.15, 0.12, 0.1, 0.95)
			else
				love.graphics.setColor(0.05, 0.05, 0.06, 0.9)
			end
			love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

			-- Thin torchlight rim / stone carving rim
			if btn.hover then
				love.graphics.setColor(0.8, 0.5, 0.2, 0.8)
			else
				love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
			end
			love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

			-- Text styling
			if btn.hover then
				love.graphics.setColor(1, 0.9, 0.7, 1)
			else
				love.graphics.setColor(0.6, 0.6, 0.65, 1)
			end
			local fontHeight = self.font and self.font:getHeight() or 16
			love.graphics.printf(btn.text, bx, by + bh / 2 - fontHeight / 2, bw, "center")
		end
	end
	love.graphics.pop()
end

function MenuScene:mousepressed(x, y, button, istouch, presses)
	if button == 1 and self.buttons then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 0.95
			end
		end
	end
end

function MenuScene:mousereleased(x, y, button, istouch, presses)
	if button == 1 and self.buttons then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 1.0
				if btn.target == "quit" then
					love.event.quit()
				else
					if SceneManager then
						SceneManager:switch(btn.target, { kind = "fade", duration = 0.4 })
					end
				end
			end
		end
	end
end

return MenuScene
