--!strict
-- Theme: палитра Okabe–Ito (различима при дальтонизме), шрифты, размеры.

local Theme = {}

Theme.hex = {
	c = "#E69F00", -- свободный член, высота прямой
	m = "#0072B2", -- наклон
	mText = "#3D9BE0", -- наклон в тексте на тёмном фоне (тот же тон, светлее для контраста)
	m_temp = "#009E73", -- коэффициент температуры
	m_dist = "#999999", -- коэффициент расстояния (лор)
	residual = "#D55E00", -- ошибки и их квадраты
	mean = "#7F7F7F", -- средние, ось вращения
	penalty = "#CC79A7", -- λ, штраф
	loss = "#56B4E9", -- функция потерь, записи на графике
	good = "#009E73",
	text = "#EDEDED",
	textDim = "#A0A0AA",
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

Theme.color = {
	c = hex(Theme.hex.c),
	m = hex(Theme.hex.m),
	mText = hex(Theme.hex.mText),
	m_temp = hex(Theme.hex.m_temp),
	m_dist = hex(Theme.hex.m_dist),
	residual = hex(Theme.hex.residual),
	mean = hex(Theme.hex.mean),
	penalty = hex(Theme.hex.penalty),
	loss = hex(Theme.hex.loss),
	good = hex(Theme.hex.good),
	text = hex(Theme.hex.text),
	textDim = hex(Theme.hex.textDim),

	bg = hex("#1E1E24"),
	panel = hex("#2A2A33"),
	panel2 = hex("#34343F"),
	grid = hex("#3A3A46"),
	axis = hex("#8A8A96"),
	line = hex("#F4F4F4"), -- прямая в мире
	flag = hex("#FFFFFF"),

	-- Мир
	soil = hex("#5B3A29"),
	wood = hex("#8B5A2B"),
	stem = hex("#3F7D3A"),
	flowerCore = hex("#F2C14E"),
	boardFrame = hex("#2B2B2B"),
	petals = { hex("#E86A92"), hex("#9B7FE6"), hex("#F28C38"), hex("#5BC0EB"), hex("#F2F2F2") },
}

-- Builder Sans — фирменный шрифт Roblox; проверь глифы Σ ŷ λ ² − на ПК и телефоне
Theme.font = Enum.Font.BuilderSans
Theme.fontMedium = Enum.Font.BuilderSansMedium
Theme.fontBold = Enum.Font.BuilderSansBold

Theme.size = {
	touch = 44, -- минимальная зона касания
	hudText = 20,
	hudSmall = 16,
}

-- RichText-обёртка цветом токена
function Theme.tok(name: string, text: string): string
	local h = Theme.hex[name] or Theme.hex.text
	return ('<font color="%s">%s</font>'):format(h, text)
end

return Theme
