do
    ---@type rech.Class
    local Class = require("rech.Class")
    ---@type rech.lib.TryImport
    local import = require("rech.lib.tryimport")
    import = import.import
    ---@type rech.dialogs.Dialog
    local Dialog = import("rech.dialogs.Dialog")
    ---@type rech.dialogs.Description
    local Description = import("rech.dialogs.fields.Description")
    ---@type rech.dialogs.TextField
    local TextField = import("rech.dialogs.fields.TextField")
    ---@type rech.dialogs.Dropdown
    local Dropdown = import("rech.dialogs.fields.Dropdown")

    ---@module rech.jaycurry.init
    local this = Class()

    local __MACRO_ID__ = "rech.q"
    local __MACRO_DIALOG_TITLE = "JayCurry UI"

    ---@type rech.jaycurry.JayCurry
    local JayCurry = require("rech.jaycurry.JayCurry")
    -- expose query as global function
    ---@return rech.jaycurry.JayCurry
    q = JayCurry.query

    -- history
    local lastQuery = ""

    function this.initMacro(parentId)

        -- add macro
        addMacroWithIcon(parentId, __MACRO_ID__, "Query", "e1b7", this.queryUI)
        addMacroWithIcon(parentId, __MACRO_ID__ .. ".help", "Syntax Help", "e887", this.helpUI)
        addMacroWithIcon(parentId, __MACRO_ID__ .. ".apihelp", "API Docs", "e873", this.apiHelpUI)
    end

    function this.queryUI()
        if Dialog == nil then notifyWarn("rech.dialogs.Dialog failed to load or is not installed!") return end
        local dialog = Dialog(__MACRO_DIALOG_TITLE)
        local tip = "Enter query expression, eg. hold[d<=10] to find floor hold less than 10ms"
        local query = TextField():label("Query"):tooltip(tip):placeholder(tip)
        query:value(lastQuery)
        local cheatsheet = [[Cheat sheet
<b>arc[tg=0]</b> Select arc in base group
<b>tap:sel</b> Select tap from currently selected notes
<b>arc.blue.void:arctap</b> Select arctap from void arc that has blue color attribute
        ]]
        dialog:add(
            Description(cheatsheet),
            query
        )
        dialog:open()
        lastQuery = query:result()
        local ret = q(query:result())
        if #ret.events.all ~= 0 then
            ret:select()
        end
        this.operationUI(ret)
    end

    local operationsHistory = {}
    ---@type table<string, fun(rech.jaycurry.JayCurry)>
    local operations = {
         ---@param r rech.jaycurry.JayCurry
        ["Nothing"] = function (r)
            notify("You decided to do nothing.")
        end,
         ---@param r rech.jaycurry.JayCurry
        ["Remove selection"] = function (r)
            local c = r:remove()
            c.name = "Remove notes"
            c.commit()
        end,
        ---@param r rech.jaycurry.JayCurry
        ["Offset event timing"] = function (r)
            local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - Offset event timing")
            local deltaTime = TextField():is_number("Please input a number"):label("Delta Time (ms)"):value("0")
            dialog:add(deltaTime)
            dialog:open()
            local c = r:offset(tonumber(deltaTime:result()))
            c.name = "Offset event timing"
            c.commit()
        end,
        ---@param r rech.jaycurry.JayCurry
        ["Move arcs"] = function (r)
            if #r.events.arc == 0 then
                warn("There's no arc to move!")
                return
            end
            local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - Move arcs")
            local oldDX = operationsHistory["dx"]
            local oldDY = operationsHistory["dy"]
            if oldDX == nil then oldDX = 0 end
            if oldDY == nil then oldDY = 0 end
            local dx = TextField():is_number("Please input a number"):label("dx"):value(tostring(oldDX))
            local dy = TextField():is_number("Please input a number"):label("dy"):value(tostring(oldDY))
            dialog:add(dx, dy)
            dialog:open()
            local c = r:movearc(tonumber(dx:result()), tonumber(dy:result()))
            c.name = "Move arcs"
            c.commit()
            operationsHistory["dx"] = tonumber(dx:result())
            operationsHistory["dy"] = tonumber(dy:result())
        end,
        ---@param r rech.jaycurry.JayCurry
        ["Copy to group"] = function (r)
            local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - to timing group")
            local dropdown = Dropdown()
            for _, tg in ipairs(JayCurry.GetTimingGroups()) do
                local name = "#" .. tg.num
                if tg.name ~= nil and tg.name ~= "" then
                    name = name .. ":" .. tg.name
                end
                if tg.num == 0 then
                    name = "Base group"
                end
                dropdown:append(name)
            end
            dropdown:label("Target group")
            dialog:add(dropdown)
            dialog:open()
            local c = r:copy(dropdown:result_num()-1)
            c.name = "Copy to group " .. (dropdown:result_num()-1)
            c.commit()
        end,
        ---@param r rech.jaycurry.JayCurry
        ["Move to group"] = function (r)
            local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - to timing group")
            local dropdown = Dropdown()
            for _, tg in ipairs(JayCurry.GetTimingGroups()) do
                local name = "#" .. tg.num
                if tg.name ~= nil and tg.name ~= "" then
                    name = name .. ":" .. tg.name
                end
                if tg.num == 0 then
                    name = "Base group"
                end
                dropdown:append(name)
            end
            dropdown:label("Target group")
            dialog:add(dropdown)
            dialog:open()
            local c = r:move(dropdown:result_num()-1)
            c.name = "Move to group " .. (dropdown:result_num()-1)
            c.commit()
        end
    }
    ---@param r rech.jaycurry.JayCurry
    function this.operationUI(r)
        if #r.events.all == 0 then
            notify("There's no any event from selection, check query again.")
            return
        end
        if Dialog == nil then notifyWarn("rech.dialogs.Dialog failed to load or is not installed!") return end
        local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - Operation")
        local summary = "Object summary:"
        if #r.events.timing > 0 then summary = summary .. "\nTimings:" .. #r.events.timing end
        if #r.events.tap > 0 then summary = summary .. "\nTaps:" .. #r.events.tap end
        if #r.events.hold > 0 then summary = summary .. "\nHolds:" .. #r.events.hold end
        if #r.events.arc > 0 then summary = summary .. "\nArcs:" .. #r.events.arc end
        if #r.events.arctap > 0 then summary = summary .. "\nArcTaps:" .. #r.events.arctap end
        if #r.events.camera > 0 then summary = summary .. "\nCameras:" .. #r.events.camera end
        if #r.events.scenecontrol > 0 then summary = summary .. "\nScenecontrols:" .. #r.events.scenecontrol end
        dialog:add(Description():label(summary)) 
        local keys={}
        for key,_ in pairs(operations) do
            keys[#keys+1] = key
        end
        local dropdown = Dropdown():set(keys):value(keys[1]):label("Select Operation")
        dialog:add(dropdown)
        dialog:open()
        operations[dropdown:result()](r)
    end

    function this.helpUI()
        if Dialog == nil then notifyWarn("rech.dialogs.Dialog failed to load or is not installed!") return end
        local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - Syntax Help")
        local help = Description(require("rech.jaycurry.help"))
        dialog:add(help)
        dialog:open()
    end

    function this.apiHelpUI()
        if Dialog == nil then notifyWarn("rech.dialogs.Dialog failed to load or is not installed!") return end
        local dialog = Dialog(__MACRO_DIALOG_TITLE .. " - API Docs")
        local apihelp = Description(require("rech.jaycurry.apihelp"))
        dialog:add(apihelp)
        dialog:open()
    end

    return this
end
