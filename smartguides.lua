-- Smart Guides Version 1.1 --
-- ©2025 YukiPixels --

---------------------------
-- Embedded JSON Library --
---------------------------

local JSON = (function()
    local obj = {}

    local function skip_ws(str, idx)
        while idx <= #str do
            local c = str:sub(idx, idx)
            if c:match('%s') then
                idx = idx + 1
            else
                break
            end
        end
        return idx
    end

    local function parse_literal(str, idx, lit, res)
        if str:sub(idx, idx + #lit - 1) == lit then
            return res, idx + #lit
        end
        error("Expected "..lit.." at index "..idx)
    end

    local function parse_number(str, idx)
        local start = idx
        if str:sub(idx, idx) == '-' then idx = idx + 1 end
        while idx <= #str and str:sub(idx, idx):match('[%d%.eE+-]') do
            idx = idx + 1
        end
        return tonumber(str:sub(start, idx - 1)), idx
    end

    local function parse_string(str, idx)
        local result = {}
        idx = idx + 1
        while idx <= #str do
            local c = str:sub(idx, idx)
            if c == '"' then
                idx = idx + 1
                return table.concat(result), idx
            elseif c == '\\' then
                idx = idx + 1
                c = str:sub(idx, idx)
                if c == 'n' then c = '\n'
                elseif c == 't' then c = '\t'
                elseif c == 'r' then c = '\r' end
            end
            table.insert(result, c)
            idx = idx + 1
        end
        error("Unclosed string at "..idx)
    end

    local function parse_array(str, idx)
        local arr = {}
        idx = skip_ws(str, idx + 1)
        while true do
            idx = skip_ws(str, idx)
            local c = str:sub(idx, idx)
            if c == ']' then return arr, idx + 1 end
            local val, err
            val, idx, err = obj.parse_value(str, idx)
            if not val then return nil, idx, err end
            table.insert(arr, val)
            idx = skip_ws(str, idx)
            if str:sub(idx, idx) == ',' then idx = skip_ws(str, idx + 1) end
        end
    end

    local function parse_object(str, idx)
        local tbl = {}
        idx = skip_ws(str, idx + 1)
        while true do
            idx = skip_ws(str, idx)
            local c = str:sub(idx, idx)
            if c == '}' then return tbl, idx + 1 end
            local key, val, err
            key, idx, err = obj.parse_value(str, idx)
            if not key then return nil, idx, err end
            idx = skip_ws(str, idx)
            if str:sub(idx, idx) ~= ':' then return nil, idx, "Expected colon" end
            val, idx, err = obj.parse_value(str, idx + 1)
            if not val then return nil, idx, err end
            tbl[key] = val
            idx = skip_ws(str, idx)
            if str:sub(idx, idx) == ',' then idx = skip_ws(str, idx + 1) end
        end
    end

    function obj.parse_value(str, idx)
        idx = idx or 1
        idx = skip_ws(str, idx)
        local c = str:sub(idx, idx)

        if c == '{' then return parse_object(str, idx)
        elseif c == '[' then return parse_array(str, idx)
        elseif c == '"' then return parse_string(str, idx)
        elseif c == '-' or c:match('%d') then return parse_number(str, idx)
        elseif c == 't' then return parse_literal(str, idx, 'true', true)
        elseif c == 'f' then return parse_literal(str, idx, 'false', false)
        elseif c == 'n' then return parse_literal(str, idx, 'null', nil)
        else error("Unexpected character '"..c.."' at "..idx) end
    end

    local function encode_value(val)
        if type(val) == 'table' then
            if val.r and val.g and val.b then
                return string.format('{"r":%d,"g":%d,"b":%d,"a":%d}',
                    val.r or 0, val.g or 0, val.b or 0, val.alpha or 255)
            end
            local items = {}
            for k, v in pairs(val) do
                table.insert(items, string.format('%s:%s',
                    encode_value(k), encode_value(v)))
            end
            return "{"..table.concat(items, ",").."}"
        elseif type(val) == 'string' then
            return '"'..val:gsub('[\\"]', '\\%0')..'"'
        elseif type(val) == 'number' then
            return tostring(val)
        elseif type(val) == 'boolean' then
            return val and "true" or "false"
        else
            return 'null'
        end
    end

    return {
        decode = function(str) return obj.parse_value(str) end,
        encode = encode_value
    }
end)()

-----------------
-- Constants --
-----------------

local GUIDE_LAYER_BASE_NAME = "Guide Layer"
local SHAPE_LAYER_BASE_NAME = "Shape Layer"

-----------------
-- Utility Functions --
-----------------

-- Check if a layer with the same name exists
local function layerExists(sprite, name)
    for _, layer in ipairs(sprite.layers) do
        if layer.name == name then
            return true
        end
    end
    return false
end

-- Generate a unique layer name
local function generateUniqueLayerName(sprite, baseName)
    local name = baseName
    local index = 1
    while layerExists(sprite, name) do
        name = baseName .. " (" .. index .. ")"
        index = index + 1
    end
    return name
end

-----------------
-- Drawing Functions --
-----------------

local function drawCrosshair(img, sprite, data)
    local vThick = math.max(1, data.thickness)
    local hThick = math.max(1, data.thickness)
    local vStart = math.floor((sprite.width - vThick) / 2)
    local hStart = math.floor((sprite.height - hThick) / 2)

    for x = vStart, vStart + vThick - 1 do
        for y = 0, sprite.height - 1 do
            img:drawPixel(x, y, data.color)
        end
    end

    for y = hStart, hStart + hThick - 1 do
        for x = 0, sprite.width - 1 do
            img:drawPixel(x, y, data.color)
        end
    end
end

local function drawShape(img, sprite, data)
    local shapeWidth = math.floor(sprite.width * data.shapeSize / 100)
    local shapeHeight = math.floor(sprite.height * data.shapeSize / 100)
    local xStart = math.floor((sprite.width - shapeWidth) / 2)
    local yStart = math.floor((sprite.height - shapeHeight) / 2)
    local thickness = math.max(1, data.shapeThickness)

    for t = 0, thickness - 1 do
        -- Top border
        for x = xStart - t, xStart + shapeWidth - 1 + t do
            img:drawPixel(x, yStart - t, data.shapeColor)
        end

        -- Bottom border
        for x = xStart - t, xStart + shapeWidth - 1 + t do
            img:drawPixel(x, yStart + shapeHeight - 1 + t, data.shapeColor)
        end

        -- Left border
        for y = yStart - t, yStart + shapeHeight - 1 + t do
            img:drawPixel(xStart - t, y, data.shapeColor)
        end

        -- Right border
        for y = yStart - t, yStart + shapeHeight - 1 + t do
            img:drawPixel(xStart + shapeWidth - 1 + t, y, data.shapeColor)
        end
    end
end

-----------------
-- Main Logic --
-----------------

function createGuidesLogic(data, sprite, SETTINGS_FILE)
    app.transaction("Create Guides", function()
        -- Create a unique name for the new Guide Layer
        local guideLayerName = generateUniqueLayerName(sprite, GUIDE_LAYER_BASE_NAME)

        -- Create new layer for crosshair
        local layer = sprite:newLayer()
        layer.name = guideLayerName
        layer.opacity = data.opacity
        local cel = sprite:newCel(layer, app.activeFrame)
        local img = Image(sprite.width, sprite.height)

        -- Draw crosshair
        drawCrosshair(img, sprite, data)
        cel.image = img

        -- Create a unique name for the new Shape Layer
        local shapeLayerName = generateUniqueLayerName(sprite, SHAPE_LAYER_BASE_NAME)

        -- Create new layer for shape
        local shapeLayer
        if data.shapeNewLayer then
            shapeLayer = sprite:newLayer()
            shapeLayer.name = shapeLayerName
            shapeLayer.opacity = data.shapeOpacity
        else
            shapeLayer = layer -- Use the same layer as the crosshair
        end

        local shapeCel = sprite:newCel(shapeLayer, app.activeFrame)
        local shapeImg = Image(sprite.width, sprite.height)

        -- Draw shape
        drawShape(shapeImg, sprite, data)
        shapeCel.image = shapeImg
    end)

    -- Save settings
    if type(SETTINGS_FILE) == "string" and SETTINGS_FILE ~= "" then
        local file = io.open(SETTINGS_FILE, "w")
        if file then
            local settingsToSave = {
                color = {
                    r = data.color.red,
                    g = data.color.green,
                    b = data.color.blue,
                    a = data.color.alpha
                },
                opacity = data.opacity,
                style = data.style:lower(),
                thickness = data.thickness,
                autoHide = data.autoHide,
                shapeSize = data.shapeSize,
                shapeColor = {
                    r = data.shapeColor.red,
                    g = data.shapeColor.green,
                    b = data.shapeColor.blue,
                    a = data.shapeColor.alpha
                },
                shapeThickness = data.shapeThickness,
                shapeStyle = data.shapeStyle:lower(),
                shapeOpacity = data.shapeOpacity,
                shapeNewLayer = data.shapeNewLayer
            }
            file:write(JSON.encode(settingsToSave))
            file:close()
        else
            app.alert("Failed to open settings file for writing: " .. SETTINGS_FILE)
        end
    else
        app.alert("Invalid settings file path: " .. tostring(SETTINGS_FILE))
    end

    app.refresh()
end

-----------------
-- UI Logic --
-----------------

function createGuides()
    local sprite = app.activeSprite
    if not sprite then
        app.alert("No active sprite")
        return
    end

    -- Defaults Configuration
    local DEFAULT_COLOR = Color{r=0, g=255, b=255, alpha=255}
    local DEFAULT_SHAPE_COLOR = Color{r=255, g=0, b=255, alpha=255}
    local SETTINGS_FILE = "smart_guides_settings.json"

    -- Initialize settings with defaults
    local settings = {
        color = DEFAULT_COLOR,
        style = "solid",
        thickness = 2,
        autoHide = false,
        opacity = 255,
        shapeSize = 80,
        shapeColor = DEFAULT_SHAPE_COLOR,
        shapeThickness = 2,
        shapeStyle = "solid",
        shapeOpacity = 255,
        shapeNewLayer = true
    }

    -- Load and validate settings
    local file = io.open(SETTINGS_FILE, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local status, result = pcall(JSON.decode, content)

        if status and type(result) == "table" then
            for k, v in pairs(result) do
                settings[k] = v
            end
        end
    end

    -- Create configuration dialog
    local dlg = Dialog("Smart Guides v1.1")

    -- Crosshair options
    dlg:separator{ text = "Crosshair Options :" }
    dlg:color{ id="color", label="Color", color=settings.color }
    dlg:slider{ id="opacity", label="Opacity", min=0, max=255, value=settings.opacity }
    dlg:slider{ id="thickness", label="Thickness", min=1, max=8, value=settings.thickness }
    dlg:combobox{ id="style", label="Line Style", options={"Solid", "Dashed", "Checkerboard"}, selected=settings.style:gsub("^%l", string.upper) }
    dlg:check{ id="autoHide", label="Hide Guides", selected=settings.autoHide }

    -- Shape options
    dlg:separator{ text = "Shape Options :" }
    dlg:slider{ id="shapeSize", label="Size (%)", min=1, max=100, value=settings.shapeSize }
    dlg:color{ id="shapeColor", label="Color", color=settings.shapeColor }
    dlg:slider{ id="shapeOpacity", label="Opacity", min=0, max=255, value=settings.shapeOpacity }
    dlg:slider{ id="shapeThickness", label="Thickness", min=1, max=8, value=settings.shapeThickness }
    dlg:combobox{ id="shapeStyle", label="Line Style", options={"Solid", "Dashed", "Checkerboard"}, selected=settings.shapeStyle:gsub("^%l", string.upper) }
    dlg:check{ id="shapeNewLayer", label="New Layer", selected=settings.shapeNewLayer }

    -- Buttons
    dlg:newrow()
    dlg:button{ id="cancel", text="  Cancel  ", onclick=function() dlg:close() end }
    dlg:button{ id="ok", text="  Create  ", onclick=function()
        dlg:close()
        createGuidesLogic(dlg.data, sprite, SETTINGS_FILE)
    end }

    dlg:show{ wait = false }
end

-----------------
-- Menu Integration --
-----------------

function init(plugin)
    app.command.register{
        id="SmartGuides",
        title="Create Smart Guides",
        group="edit",
        onclick=createGuides
    }
end

function exit() end

createGuides()