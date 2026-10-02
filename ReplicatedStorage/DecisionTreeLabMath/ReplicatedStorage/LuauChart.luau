--!strict
--!native
--!optimize 2

-- LuauChart by ParadoxSoftwork (https://devforum.roblox.com/t/2d-graph-renderer/4216527)
-- Support: https://devforum.roblox.com/t/luauchart-graph-chart-renderer/4864869/2
-- Version 1.1.1

-- ─── Dependencies ────────────────────────────────────────────────────────────

const Charts = require(script.Internal.Charts)
const Image = script.Renderers.Image
const Viewport = script.Renderers.Viewport

-- ─── Package ─────────────────────────────────────────────────────────────────

return Charts.Build({
	Image = {
		Assets = Image.Assets,
		Line = require(Image.Line),
		Bar = require(Image.Bar),
		Pie = require(Image.Pie),
		Candle = require(Image.Candle),
		Box = require(Image.Box),
		Heatmap = require(Image.Heatmap),
		Treemap = require(Image.Treemap),
		Radar = require(Image.Radar),
	},
	Viewport = {
		Assets = Viewport.Assets,
		Line = require(Viewport.Line),
		Bar = require(Viewport.Bar),
		Pie = require(Viewport.Pie),
		Candle = require(Viewport.Candle),
		Box = require(Viewport.Box),
		Heatmap = require(Viewport.Heatmap),
		Treemap = require(Viewport.Treemap),
		Radar = require(Viewport.Radar),
	},
}, "Image")
