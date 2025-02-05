-- Copyright (c) 2021 Maxim Tuprikov <insality@gmail.com>. This code is licensed under MIT license

--- Component to handle all GUI texts.
-- Druid text can adjust itself for text node size
-- Text will never will be outside of his text size (even multiline)
-- @module Text
-- @within BaseComponent
-- @alias druid.text

--- On set text callback(self, text)
-- @tfield druid_event on_set_text

--- On adjust text size callback(self, new_scale)
-- @tfield druid_event on_update_text_scale

--- On change pivot callback(self, pivot)
-- @tfield druid_event on_set_pivot

--- Text node
-- @tfield node node

--- The node id of text node
-- @tfield hash node_id

--- Current text position
-- @tfield vector3 pos

--- Initial text node scale
-- @tfield vector3 start_scale

--- Current text node scale
-- @tfield vector3 scale

--- Initial text node size
-- @tfield vector3 start_size

--- Current text node available are
-- @tfield vector3 text_area

--- Current text size adjust settings
-- @tfield number adjust_type

--- Current text color
-- @tfield vector3 color

---

local Event = require("druid.event")
local const = require("druid.const")
local utf8 = require("druid.system.utf8")
local component = require("druid.component")

local Text = component.create("text", { component.ON_LAYOUT_CHANGE, component.ON_MESSAGE_INPUT })


local function update_text_size(self)
	local size = vmath.vector3(
		self.start_size.x * (self.start_scale.x / self.scale.x),
		self.start_size.y * (self.start_scale.y / self.scale.y),
		self.start_size.z
	)
	gui.set_size(self.node, size)
end


--- Reset initial scale for text
local function reset_default_scale(self)
	gui.set_scale(self.node, self.start_scale)
	gui.set_size(self.node, self.start_size)
end


--- Setup scale x, but can only be smaller, than start text scale
local function update_text_area_size(self)
	reset_default_scale(self)

	local max_width = self.text_area.x
	local max_height = self.text_area.y

	local metrics = gui.get_text_metrics_from_node(self.node)

	local scale_modifier = max_width / metrics.width
	scale_modifier = math.min(scale_modifier, self.start_scale.x)

	if self:is_multiline() then
		local max_text_area_square = max_width * max_height
		local cur_text_area_square = metrics.height * metrics.width * self.start_scale.x
		scale_modifier = self.start_scale.x * math.sqrt(max_text_area_square / cur_text_area_square)
	end

	if self._minimal_scale then
		scale_modifier = math.max(scale_modifier, self._minimal_scale)
	end

	local new_scale = vmath.vector3(scale_modifier, scale_modifier, self.start_scale.z)
	gui.set_scale(self.node, new_scale)
	self.scale = new_scale

	update_text_size(self)

	self.on_update_text_scale:trigger(self:get_context(), new_scale)
end


local function update_text_with_trim(self, trim_postfix)
	local max_width = self.text_area.x
	local text_width = self:get_text_width()

	if text_width > max_width then
		local text_length = utf8.len(self.last_value)
		local new_text = self.last_value
		while text_width > max_width do
			text_length = text_length - 1
			new_text = utf8.sub(self.last_value, 1, text_length)
			text_width = self:get_text_width(new_text .. trim_postfix)
		end

		gui.set_text(self.node, new_text .. trim_postfix)
	end
end


local function update_text_with_anchor_shift(self)
	if self:get_text_width() >= self.text_area.x then
		self:set_pivot(const.REVERSE_PIVOTS[self.start_pivot])
	else
		self:set_pivot(self.start_pivot)
	end
end


-- calculate space width with font
local function get_space_width(self, font)
	if not self._space_width[font] then
		local no_space = gui.get_text_metrics(font, "1", 0, false, 0, 0).width
		local with_space = gui.get_text_metrics(font, " 1", 0, false, 0, 0).width
		self._space_width[font] = with_space - no_space
	end

	return self._space_width[font]
end


local function update_adjust(self)
	if not self.adjust_type or self.adjust_type == const.TEXT_ADJUST.NO_ADJUST then
		reset_default_scale(self)
		return
	end

	if self.adjust_type == const.TEXT_ADJUST.DOWNSCALE then
		update_text_area_size(self)
	end

	if self.adjust_type == const.TEXT_ADJUST.TRIM then
		update_text_with_trim(self, self.style.TRIM_POSTFIX)
	end

	if self.adjust_type == const.TEXT_ADJUST.DOWNSCALE_LIMITED then
		update_text_area_size(self)
	end

	if self.adjust_type == const.TEXT_ADJUST.SCROLL then
		update_text_with_anchor_shift(self)
	end

	if self.adjust_type == const.TEXT_ADJUST.SCALE_THEN_SCROLL then
		update_text_area_size(self)
		update_text_with_anchor_shift(self)
	end
end


--- Component style params.
-- You can override this component styles params in druid styles table
-- or create your own style
-- @table style
-- @tfield[opt=...] string TRIM_POSTFIX The postfix for TRIM adjust type
-- @tfield[opt=DOWNSCALE] string DEFAULT_ADJUST The default adjust type for any text component
function Text.on_style_change(self, style)
	self.style = {}
	self.style.TRIM_POSTFIX = style.TRIM_POSTFIX or "..."
	self.style.DEFAULT_ADJUST = style.DEFAULT_ADJUST or const.TEXT_ADJUST.DOWNSCALE
end


--- Component init function
-- @tparam Text self
-- @tparam node node Gui text node
-- @tparam[opt] string value Initial text. Default value is node text from GUI scene.
-- @tparam[opt=0] int adjust_type Adjust type for text. By default is DOWNSCALE. Look const.TEXT_ADJUST for reference
function Text.init(self, node, value, adjust_type)
	self.node = self:get_node(node)
	self.pos = gui.get_position(self.node)
	self.node_id = gui.get_id(self.node)

	self.start_pivot = gui.get_pivot(self.node)
	self.start_scale = gui.get_scale(self.node)
	self.scale = gui.get_scale(self.node)

	self.start_size = gui.get_size(self.node)
	self.text_area = gui.get_size(self.node)
	self.text_area.x = self.text_area.x * self.start_scale.x
	self.text_area.y = self.text_area.y * self.start_scale.y

	self.adjust_type = adjust_type or self.style.DEFAULT_ADJUST
	self.color = gui.get_color(self.node)

	self.on_set_text = Event()
	self.on_set_pivot = Event()
	self.on_update_text_scale = Event()

	self._space_width = {}

	self:set_to(value or gui.get_text(self.node))
	return self
end


function Text.on_layout_change(self)
	self:set_to(self.last_value)
end


function Text.on_message_input(self, node_id, message)
	if node_id ~= self.node_id  then
		return false
	end

	if message.action == const.MESSAGE_INPUT.TEXT_SET then
		Text.set_to(self, message.value)
	end
end


--- Calculate text width with font with respect to trailing space
-- @tparam Text self
-- @tparam[opt] string text
function Text.get_text_width(self, text)
	text = text or self.last_value
	local font = gui.get_font(self.node)
	local scale = gui.get_scale(self.node)
	local result = gui.get_text_metrics(font, text, 0, false, 0, 0).width
	for i = #text, 1, -1 do
		local c = string.sub(text, i, i)
		if c ~= ' ' then
			break
		end

		result = result + get_space_width(self, font)
	end

	return result * scale.x
end


--- Set text to text field
-- @tparam Text self
-- @tparam string set_to Text for node
-- @treturn Text Current text instance
function Text.set_to(self, set_to)
	set_to = set_to or ""

	self.last_value = set_to
	gui.set_text(self.node, set_to)

	self.on_set_text:trigger(self:get_context(), set_to)

	update_adjust(self)

	return self
end


--- Set color
-- @tparam Text self
-- @tparam vector4 color Color for node
-- @treturn Text Current text instance
function Text.set_color(self, color)
	self.color = color
	gui.set_color(self.node, color)

	return self
end


--- Set alpha
-- @tparam Text self
-- @tparam number alpha Alpha for node
-- @treturn Text Current text instance
function Text.set_alpha(self, alpha)
	self.color.w = alpha
	gui.set_color(self.node, self.color)

	return self
end


--- Set scale
-- @tparam Text self
-- @tparam vector3 scale Scale for node
-- @treturn Text Current text instance
function Text.set_scale(self, scale)
	self.last_scale = scale
	gui.set_scale(self.node, scale)

	return self
end


--- Set text pivot. Text will re-anchor inside text area
-- @tparam Text self
-- @tparam gui.pivot pivot Gui pivot constant
-- @treturn Text Current text instance
function Text.set_pivot(self, pivot)
	local prev_pivot = gui.get_pivot(self.node)
	local prev_offset = const.PIVOTS[prev_pivot]

	gui.set_pivot(self.node, pivot)
	local cur_offset = const.PIVOTS[pivot]

	local pos_offset = vmath.vector3(
		self.text_area.x * (cur_offset.x - prev_offset.x),
		self.text_area.y * (cur_offset.y - prev_offset.y),
		0
	)

	self.pos = self.pos + pos_offset
	gui.set_position(self.node, self.pos)

	self.on_set_pivot:trigger(self:get_context(), pivot)

	return self
end


--- Return true, if text with line break
-- @tparam Text self
-- @treturn bool Is text node with line break
function Text.is_multiline(self)
	return gui.get_line_break(self.node)
end


--- Set text adjust, refresh the current text visuals, if needed
-- @tparam Text self
-- @tparam[opt] number adjust_type See const.TEXT_ADJUST. If pass nil - use current adjust type
-- @tparam[opt] number minimal_scale If pass nil - not use minimal scale
-- @treturn Text Current text instance
function Text.set_text_adjust(self, adjust_type, minimal_scale)
	self.adjust_type = adjust_type
	self._minimal_scale = minimal_scale
	self:set_to(self.last_value)

	return self
end


--- Set minimal scale for DOWNSCALE_LIMITED or SCALE_THEN_SCROLL adjust types
-- @tparam Text self
-- @tparam number minimal_scale If pass nil - not use minimal scale
-- @treturn Text Current text instance
function Text.set_minimal_scale(self, minimal_scale)
	self._minimal_scale = minimal_scale

	return self
end


--- Return current text adjust type
-- @treturn number The current text adjust type
function Text.get_text_adjust(self, adjust_type)
	return self.adjust_type
end


return Text
