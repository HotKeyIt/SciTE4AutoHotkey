-- ahk.lua
-- =======

-- Part of SciTE4AutoHotkey
-- This file implements features specific to AutoHotkey in SciTE
-- Do NOT edit this file, use UserLuaScript.lua instead!

-- Functions:
--     AutoIndent for AutoHotkey
--     Some AutoComplete tweaks
--     Automatic backups
--     SciTEDebug.ahk DBGp debugger interface

-- ======================= --
-- AutoHotkey lexer styles --
-- ======================= --

local SCLEX_AHK1           = 200
local SCE_AHK_DEFAULT      =  0
local SCE_AHK_COMMENTLINE  =  1
local SCE_AHK_COMMENTBLOCK =  2
local SCE_AHK_ESCAPE       =  3
local SCE_AHK_SYNOPERATOR  =  4
local SCE_AHK_EXPOPERATOR  =  5
local SCE_AHK_STRING       =  6
local SCE_AHK_NUMBER       =  7
local SCE_AHK_IDENTIFIER   =  8
local SCE_AHK_VARREF       =  9
local SCE_AHK_LABEL        = 10
local SCE_AHK_WORD_CF      = 11
local SCE_AHK_WORD_CMD     = 12
local SCE_AHK_WORD_FN      = 13
local SCE_AHK_WORD_DIR     = 14
local SCE_AHK_WORD_KB      = 15
local SCE_AHK_WORD_VAR     = 16
local SCE_AHK_WORD_SP      = 17
local SCE_AHK_WORD_UD      = 18
local SCE_AHK_VARREFKW     = 19
local SCE_AHK_ERROR        = 20

local prepared = false
local savedbk = nil

-- ================================================== --
-- OnClear event - fired when SciTE changes documents --
-- ================================================== --

function OnClear()
	-- This function only works with the AutoHotkey lexer
	--if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	if not prepared then
		-- Remove the current line markers.
		ClearAllMarkers()
	end
	
	SetMarkerColors()
	editor.MarginSensitiveN[1] = true
end

-- ====================================== --
-- OnChar event - needed by some features --
-- ====================================== --

function OnChar(curChar)
	local ignoreStyles = {SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK, SCE_AHK_STRING, SCE_AHK_ERROR, SCE_AHK_ESCAPE}
	
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end

	if curChar == "\n" then
		local prevStyle = editor.StyleAt[getPrevLinePos()]
		if not isInTable(ignoreStyles, prevStyle) then
			return AutoIndent_OnNewLine()
		end
	elseif curChar == "{" then
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		if not isInTable(ignoreStyles, curStyle) then
			AutoIndent_OnOpeningBrace()
		end
	elseif curChar == "}" then
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		if not isInTable(ignoreStyles, curStyle) then
			AutoIndent_OnClosingBrace()
		end
	elseif curChar == "." then
		return CancelAutoComplete()
	else
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		
		-- Disable AutoComplete on comment/string/error/etc.
		if isInTable(ignoreStyles, curStyle) then
			return CancelAutoComplete()
		end
		
		-- Disable AutoComplete for words that start with underscore if it's not an object call
		local pos = editor:WordStartPosition(editor.CurrentPos)
		-- _ and .
		if editor.CharAt[pos] == 95 and editor.CharAt[pos-1] ~= 46 then
			return CancelAutoComplete()
		end
	end
	
	return false
end

function CancelAutoComplete()
	if editor:AutoCActive() then
		editor:AutoCCancel()
	end
	return true
end

-- ================================================== --
-- OnMarginClick event - needed to set up breakpoints --
-- ================================================== --

function OnMarginClick(position, margin)
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	if margin == 1 then
		if prepared then
			return pumpmsg(4112, 1, editor:LineFromPosition(position))
		else
			line = editor:LineFromPosition(position)
			if editor:MarkerNext(line, 1024) == line then -- 1024 = BIT(10)
				editor:MarkerDelete(line, 10)
			else
				editor:MarkerAdd(line, 10)
			end
			return true
		end
	else
		return false
	end
end

-- =============================================== --
-- OnDwellStart event - used to implement hovering --
-- =============================================== --

function OnDwellStart(pos, s)
	if not prepared then return end
	if s ~= '' then
		pumpmsgstr(4112, 4, GetWord(pos))
	else
		pumpmsgstr(4112, 4, "")
	end
end

-- =========================================================== --
-- Get direction interface HWND function (used by the toolbar) --
-- =========================================================== --

function get_director_HWND()
	if prepared then return end
	
	if localizewin("scite4ahkToolbarTempWin") == false then
		print("Window doesn't exist.")
		return
	end
	
	pumpmsg(4099, 0, props['WindowID'])
end

-- ============== --
-- DBGp functions --
-- ============== --
-- The following are only reachable when an AutoHotkey script
-- is open so there's no need to check the lexer

function DBGp_Connect()
	if prepared then return end
	
	if localizewin("SciTEDebugStub") == false then
		print("Window doesn't exist.")
		return
	end
	
	-- Initialize
	pumpmsg(4112, 0, 0)
	prepared = true
	--SetMarkerColors()
	ClearAllMarkers()
	savedbk = enumBreakpoints()
end

function enumBreakpoints()
	line = editor:MarkerNext(0, 1024) -- 1024 = BIT(10)
	if line ~= -1 then
		i = 2
		tbl = { line }
		while true do
			line = editor:MarkerNext(line+1, 1024)
			if line == -1 then break end
			tbl[i] = line
			i = i + 1
		end
		return tbl
	end
	return nil
end

function DBGp_BkReset()
	if savedbk == nil then return end
	
	editor:MarkerDeleteAll(10)
	for i,v in ipairs(savedbk) do
		pumpmsg(4112, 1, v)
	end
	
	savedbk = nil
end

function DBGp_Disconnect()
	-- Deinitialize
	u = pumpmsg(4112, 255, 0)
	if u == 0 then return false end
	
	--editor.MarginSensitiveN[1] = false
	prepared = false
	ClearAllMarkers()
end

function DBGp_Inspect()
	if not prepared then return end
	pumpmsgstr(4112, 2, GetCurWord())
end

function DBGp_Run()
	if not prepared then return end
	pumpmsgstr(4112, 3, "run")
end

function DBGp_Stop()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stop")
end

function DBGp_StepInto()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepinto")
end

function DBGp_StepOver()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepover")
end

function DBGp_StepOut()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepout")
end

function DBGp_Stacktrace()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stacktrace")
end

function DBGp_Varlist()
	if not prepared then return end
	pumpmsgstr(4112, 3, "varlist")
end

-- ============================================================ --
-- AutoIndent section - it implements AutoIndent for AutoHotkey --
-- ============================================================ --

-- Patterns for syntax matching
--local varCharPat = "[#_@%w%[%]%$%?]"
local varCharPat = "[#_@%w%$]"
local ifPat = "[iI][fF]"
local altIfPat = ifPat.."%a+"
local whilePat = "[wW][hH][iI][lL][eE]"
local loopPat = "[lL][oO][oO][pP]"
local forPat = "[fF][oO][rR]"
local elsePat = "[eE][lL][sS][eE]"
local tryPat = "[tT][rR][yY]"
local catchPat = "[cC][aA][tT][cC][hH]"

-- Functions to detect certain types of statements

function isOpenBraceLine(line)
	return string.find(line, "^%s*{") ~= nil
end

function isIfLine(line)
	return string.find(line, "^%s*"..ifPat.."%s+"..varCharPat) ~= nil
		or string.find(line, "^%s*"..ifPat.."%s*%(") ~= nil
		or string.find(line, "^%s*"..ifPat.."%s+!") ~= nil
		or string.find(line, "^%s*"..altIfPat.."%s*,") ~= nil
		or string.find(line, "^%s*"..altIfPat.."%s+") ~= nil
end

function isIfLineNoBraces(line)
	return isIfLine(line) and string.find(line, "{%s*$") == nil
end

function isTryLine(line)
	return string.find(line, "^%s*"..tryPat.."%s+$") ~= nil
end

function isTryLineAllowBraces(line)
	return isTryLine(line) or string.find(line, "^%s*"..tryPat.."%s*{%s*$") ~= nil
end

function isWhileLine(line)
	return string.find(line, "^%s*"..whilePat.."%s+") ~= nil
		or string.find(line, "^%s*"..whilePat.."%s*%(") ~= nil
end

function isLoopLine(line)
	return string.find(line, "^%s*"..loopPat.."%s*,") ~= nil
		or string.find(line, "^%s*"..loopPat.."%s+") ~= nil
end

function isForLine(line)
	return string.find(line, "^%s*"..forPat.."%s+"..varCharPat) ~= nil
end

function isLoopLineAllowBraces(line)
	return isLoopLine(line) or string.find(line, "^%s*"..loopPat.."%s*{%s*$") ~= nil
end

function isElseLine(line)
	return string.find(line, "^%s*"..elsePat.."%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..elsePat.."%s*$") ~= nil
end

function isElseWithClosingBrace(line)
	return string.find(line, "^%s*}%s*"..elsePat.."%s*$") ~= nil
end

function isElseLineAllowBraces(line)
	return isElseLine(line) or isElseWithClosingBrace(line)
		or string.find(line, "^%s*"..elsePat.."%s*{%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..elsePat.."%s*{%s*$") ~= nil
end

function isCatchLine(line)
	return string.find(line, "^%s*"..catchPat.."%s*$") ~= nil
		or string.find(line, "^%s*"..catchPat.."%s+"..varCharPat.."+%s*$") ~= nil
end

function isCatchAllowClosingBrace(line)
	return isCatchLine(line)
		or string.find(line, "^%s*}%s*"..catchPat.."%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..catchPat.."%s+"..varCharPat.."+%s*$") ~= nil
end

function isCatchLineAllowBraces(line)
	return isCatchLine(line) or isCatchAllowClosingBrace(line)
		or string.find(line, "^%s*"..catchPat.."%s*{%s*$") ~= nil
		or string.find(line, "^%s*"..catchPat.."%s+"..varCharPat.."+%s*{%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..catchPat.."%s*{%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..catchPat.."%s+"..varCharPat.."+%s*{%s*$") ~= nil
end


function isFuncDef(line)
	return string.find(line, "^%s*"..varCharPat.."+%(.*%)%s*{%s*$") ~= nil
end

function isSingleLineIndentStatement(line)
	return isIfLineNoBraces(line) or isElseLine(line) or isElseWithClosingBrace(line)
		or isWhileLine(line) or isForLine(line) or isLoopLine(line)
		or isTryLine(line) or isCatchAllowClosingBrace(line)
end

function isIndentStatement(line)
	return isOpenBraceLine(line) or isIfLine(line) or isWhileLine(line) or isForLine(line)
		or isLoopLineAllowBraces(line) or isElseLineAllowBraces(line) or isFuncDef(line)
		or isTryLineAllowBraces(line) or isCatchLineAllowBraces(line)
end

function isStartBlockStatement(line)
	return isIfLine(line) or isWhileLine(line) or isLoopLine(line)  or isForLine(line)
		or isElseLine(line) or isElseWithClosingBrace(line)
		or isTryLine(line) or isCatchLineAllowBraces(line)
end

-- This function is called when the user presses {Enter}
function AutoIndent_OnNewLine()
	local prevprevPos = editor:LineFromPosition(editor.CurrentPos) - 2
	local prevPos = editor:LineFromPosition(editor.CurrentPos) - 1
	local prevLine = GetFilteredLine(prevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local curPos = prevPos + 1
	local curLine = editor:GetLine(curPos)
	
	if curLine ~= nil and string.find(curLine, "^%s*[^%s]+") then return end
	
	if isIndentStatement(prevLine) then
		editor:Home()
		editor:Tab()
		editor:LineEnd()
	elseif prevprevPos >= 0 then
		local prevprevLine = GetFilteredLine(prevprevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
		local reqLvl = editor.LineIndentation[prevprevPos] + editor.Indent
		local prevLvl = editor.LineIndentation[prevPos]
		local curLvl = editor.LineIndentation[curPos]
		if isSingleLineIndentStatement(prevprevLine) and prevLvl == reqLvl and curLvl == reqLvl then
			editor:Home()
			editor:BackTab()
			editor:LineEnd()
			return true
		end
	end
	return false
end

-- This function is called when the user presses {
function AutoIndent_OnOpeningBrace()
	local prevPos = editor:LineFromPosition(editor.CurrentPos) - 1
	local curPos = prevPos+1
	if prevPos == -1 then return false end
	
	if editor.LineIndentation[curPos] == 0 then return false end
	
	local prevLine = GetFilteredLine(prevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local curLine = GetFilteredLine(curPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	
	if string.find(curLine, "^%s*{%s*$") and isStartBlockStatement(prevLine)
		and (editor.LineIndentation[curPos] > editor.LineIndentation[prevPos]) then
		editor:Home()
		editor:BackTab()
		editor:LineEnd()
	end
end

-- This function is called when the user presses }
function AutoIndent_OnClosingBrace()
	local curPos = editor:LineFromPosition(editor.CurrentPos)
	local curLine = GetFilteredLine(curPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local prevPos = curPos - 1
	local prevprevPos = prevPos - 1
	local secondChance = false
	
	if curPos == 0 then return false end
	if editor.LineIndentation[curPos] == 0 then return false end
	
	if prevprevPos >= 0 then
		local prevprevLine = GetFilteredLine(prevprevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
		local lowLvl = editor.LineIndentation[prevprevPos]
		local highLvl = lowLvl + editor.Indent
		local prevLvl = editor.LineIndentation[prevPos]
		local curLvl = editor.LineIndentation[curPos]
		if isSingleLineIndentStatement(prevprevLine) and prevLvl == highLvl and curLvl == lowLvl then
			secondChance = true
		end
	end
	
	if string.find(curLine, "^%s*}%s*$") and (editor.LineIndentation[curPos] >= editor.LineIndentation[prevPos] or secondChance) then
		editor:Home()
		editor:BackTab()
		editor:LineEnd()
	end
end

-- ====================== --
-- Script Backup Function --
-- ====================== --

-- this functions creates backups for the files

function OnBeforeSave(filename)
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	if props['make.backup'] == "1" then
		os.remove(filename .. ".bak")
		os.rename(filename, filename .. ".bak")
	end
end

-- ============= --
-- Open #Include --
-- ============= --

function OpenInclude()
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	local CurrentLine = editor:GetLine(editor:LineFromPosition(editor.CurrentPos))
	if not string.find(CurrentLine, "^%s*%#[Ii][Nn][Cc][Ll][Uu][Dd][Ee]") then
		print("Not an include line!")
		return
	end
	local place = string.find(CurrentLine, "%#[Ii][Nn][Cc][Ll][Uu][Dd][Ee]")
	local IncFile = string.sub(CurrentLine, place + 8)
	if string.find(IncFile, "^[Aa][Gg][Aa][Ii][Nn]") then
		IncFile = string.sub(IncFile, 6)
	end
	IncFile = string.gsub(IncFile, "\r", "")  -- strip CR
	IncFile = string.gsub(IncFile, "\n", "")  -- strip LF
	IncFile = string.sub(IncFile, 2)          -- strip space at the beginning
	IncFile = string.gsub(IncFile, "*i ", "") -- strip *i option
	IncFile = string.gsub(IncFile, "*I ", "")
	-- Delete comments
	local cplace = string.find(IncFile, "%s*;")
	if cplace then
		IncFile = string.sub(IncFile, 1, cplace-1)
	end
	
	-- Delete spaces at the beginning and the end
	IncFile = string.gsub(IncFile, "^%s*", "")
	IncFile = string.gsub(IncFile, "%s*$", "")
	
	-- Replace variables
	IncFile = string.gsub(IncFile, "%%[Aa]_[Ss][Cc][Rr][Ii][Pp][Tt][Dd][Ii][Rr]%%", props['FileDir'])
	
	a,b,IncLib = string.find(IncFile, "^<(.+)>$")
	
	if IncLib ~= nil then
	
		local IncLib2 = IncLib
		local RawIncLib = IncLib
		a,b,whatmatch = string.find(IncLib, "^(.-)_")
		if whatmatch ~= nil and whatmatch ~= "" then
			IncLib2 = whatmatch
		end
		IncLib = "\\"..IncLib..".ahk"
		IncLib2 = "\\"..IncLib2..".ahk"
		
		local GlobalLib = props['AutoHotkeyDir'].."\\Lib"
		local UserLib = props['SciteUserHome'].."\\..\\Lib"
		local LocalLib = props['FileDir'].."\\Lib"
		
		for i,LibDir in ipairs({GlobalLib, UserLib, LocalLib}) do
			if FileExists(LibDir..IncLib) then
				scite.Open(LibDir..IncLib)
				return
			elseif FileExists(LibDir..IncLib2) then
				scite.Open(LibDir..IncLib2)
				return
			end
		end
		
		print("Library not found! Specified: '"..RawIncLib.."'")
		
	elseif FileExists(IncFile) then
		scite.Open(IncFile)
	else
		print("File not found! Specified: '"..IncFile.."'")
	end
end

-- ================ --
-- Helper Functions --
-- ================ --

function GetWord(pos)
	from = editor:WordStartPosition(pos)
	to = editor:WordEndPosition(pos)
	return editor:textrange(from, to)
end

function GetCurWord()
	local word = editor:GetSelText()
	if word == "" then
		word = GetWord(editor.CurrentPos)
	end
	return word
end

function getPrevLinePos()
	local line = editor:LineFromPosition(editor.CurrentPos)-1
	local linepos = editor:PositionFromLine(line)
	local linetxt = editor:GetLine(line)
	return linepos + string.len(linetxt) - 1
end

function isInTable(table, elem)
	for k,i in ipairs(table) do
		if i == elem then
			return true
		end
	end
	return false
end

function GetFilteredLine(linen, style1, style2)
	unline = editor:GetLine(linen)
	lpos = editor:PositionFromLine(linen)
	q = 0
	for i = 0, string.len(unline)-1 do
		if(editor.StyleAt[lpos+i] == style1 or editor.StyleAt[lpos+i] == style2) then
			unline = unline:sub(1, i).."\000"..unline:sub(i+2)
		end
	end
	unline = string.gsub(unline, "%z", "")
	return unline
end

function SetMarkerColors()
	editor:MarkerDefine(10, 0)  -- breakpoint
	editor:MarkerSetBack(10, 0x0000FF)
	editor:MarkerDefine(11, 2)  -- current line arrow
	editor:MarkerSetBack(11, 0xFFFF00)
	editor:MarkerDefine(12, 22) -- current line highlighting
	editor:MarkerSetBack(12, 0xFFFF00)
end

function ClearAllMarkers()
	--editor:MarkerDeleteAll(10)
	editor:MarkerDeleteAll(11)
	editor:MarkerDeleteAll(12)
end

-- ======================= --
-- User Lua script loading --
-- ======================= --

function FileExists(file)
	local fobj = io.open(file, "r")
	if fobj then
		fobj:close()
		return true
	else
		return false
	end
end

local userlua = props['SciteUserHome'].."/UserLuaScript.lua"
if FileExists(userlua) then
	dofile(userlua)
end
