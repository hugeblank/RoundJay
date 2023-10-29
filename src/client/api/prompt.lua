--- read() but better for this use case.
---@param nt Term
---@param history string[]?
---@param fnComplete nil|fun(input: string): string[]
---@return string
local function prompt(nt, history, fnComplete)
    if not history then
        history = {}
    end
    local chars, pos, held, redraw, histpos = {}, 1, {}, false, #history+1
    local cx, cy = nt.getCursorPos()
    local sx = nt.getSize()
    local cmptable, cmpind, cmpstr
    local function jumpForward()
        local boundary = #chars + 1
        for i = pos, #chars do
            boundary = i + 1
            if chars[i] == " " and boundary ~= pos then
                break
            end
        end
        return boundary
    end
    local function jumpBackward()
        local boundary = 1
        for i = pos, 0, -1 do
            boundary = i + 1
            if chars[i] == " " and boundary ~= pos then
                break
            end
        end
        return boundary
    end
    while true do
        local e, key = os.pullEvent()
        local ot = term.redirect(nt)
        if e == "key" then
            if key == keys.tab and pos == #chars + 1 and cmptable then
                local word = cmpstr:gsub(" (.*)$", function(remainder)
                    if #remainder > 0 then
                        cmpstr = remainder
                        return " "
                    else
                        cmpstr = nil
                        return ""
                    end
                end)
                if #word > 0 then
                    for char in word:gmatch(".") do
                        chars[#chars + 1] = char
                    end
                    pos = #chars + 1
                    cmpind = 1
                end
            elseif key == keys.up then
                if cmptable and pos == #chars + 1 then
                    if cmptable[cmpind + 1] then
                        cmpind = cmpind + 1
                    elseif cmpind == #cmptable then
                        cmpind = 1
                    end
                elseif history[histpos - 1] then
                    histpos = histpos - 1
                    chars = {}
                    for char in history[histpos]:gmatch(".") do
                        chars[#chars + 1] = char
                    end
                    pos = #chars + 1
                end
                cmpstr = nil
            elseif key == keys.down then
                if cmptable and pos == #chars + 1 then
                    if cmptable[cmpind - 1] then
                        cmpind = cmpind - 1
                    elseif cmpind == 1 then
                        cmpind = #cmptable
                    end
                elseif histpos <= #history then
                    if histpos == #history then
                        chars, pos = {}, 1
                    else
                        chars = {}
                        for char in history[histpos + 1]:gmatch(".") do
                            chars[#chars + 1] = char
                        end
                        pos = #chars + 1
                    end
                    histpos = histpos + 1
                end
                cmpstr = nil
            elseif key == keys.left then
                if held[keys.leftCtrl] then
                    pos = jumpBackward()
                else
                    pos = pos - 1
                end
            elseif key == keys.right then
                if held[keys.leftCtrl] then
                    pos = jumpForward()
                else
                    pos = pos + 1
                end
            elseif key == keys.backspace and pos > 1 then
                if held[keys.leftCtrl] then
                    local clearto = jumpBackward()
                    for i = 1, pos - clearto do
                        table.remove(chars, clearto)
                    end
                    pos = clearto
                else
                    table.remove(chars, pos - 1)
                    pos = pos - 1
                end
                cmpstr = nil
            elseif key == keys.delete and pos <= #chars then
                if held[keys.leftCtrl] then
                    local clearup = jumpForward()
                    for i = 1, clearup - pos do
                        table.remove(chars, pos)
                    end
                else
                    table.remove(chars, pos)
                end
                cmpstr = nil
            elseif key == keys.home then
                pos = 1
            elseif key == keys["end"] then
                if cmptable and pos == #chars + 1 then
                    for char in cmptable[cmpind]:gmatch(".") do
                        chars[#chars + 1] = char
                    end
                    cmpind = 1
                    cmpstr = nil
                else
                    pos = #chars + 1
                end
            elseif key == keys.enter then
                term.setCursorPos(cx, cy)
                term.clearLine()
                term.redirect(ot)
                return table.concat(chars)
            end
            if pos > #chars + 1 then
                pos = #chars + 1
            elseif pos < 1 then
                pos = 1
            end
            held[key] = true
            redraw = true
        elseif e == "char" then
            table.insert(chars, pos, key)
            pos = pos + 1
            redraw = true
            cmpstr = nil
        elseif e == "key_up" then
            held[key] = false
        end
        if redraw then
            if fnComplete then
                cmptable = fnComplete(table.concat(chars))
                if cmptable then
                    if not cmpind then
                        cmpind = 1
                    end
                    if not cmpstr then
                        cmpstr = cmptable[cmpind]
                    end
                end
                if not cmptable or #cmptable == 0 or #chars == 0 then
                    cmptable, cmpind, cmpstr = nil, nil, nil
                end
            end
            term.setCursorPos(cx, cy)
            term.write((" "):rep(sx - cx))
            term.setCursorPos(cx, cy)
            term.write(table.concat(chars, nil, math.max(1, #chars - (sx - cx + 1) + 2), #chars))
            if cmpstr then
                local otxc = term.getTextColor()
                term.setTextColor(colors.lightGray)
                term.write(cmpstr)
                term.setTextColor(otxc)
            end
            redraw = false
        end
        term.setCursorBlink(true)
        term.setCursorPos(cx + math.min(pos - 1, sx - cx), cy)
        term.redirect(ot)
    end
end

return prompt