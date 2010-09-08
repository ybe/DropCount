
if (not DuckMod_Widgets_Version) then
	DuckMod_Widgets_Version=0;
end


if (DuckMod_Widgets_Version<1) then				-- This version
	DuckMod_Widgets_Version=1;

	DM_STATE_LIST=0;
	DM_STATE_INACTIVE=1;
	DM_STATE_CHECKED=2;
	DM_STATE_UNCHECKED=3;

	if (not DuckWidget) then DuckWidget={}; end	-- If it exists, just overlay
	if (not DuckWidget.ListBox) then DuckWidget.ListBox={}; end	-- If it exists, just overlay
	if (not DuckWidget.CheckBox) then DuckWidget.CheckBox={}; end	-- If it exists, just overlay

-- Generic mouse-wheel handler for scrolling-panes.
-- o The main use for this is when a pane has other items in it that
--   may receive it in stead. They may then call this function with
--   their parent as an argument.
function DuckWidget.MouseWheel(slider)
	if (not slider) then slider=this; end
	local min,max=slider:GetMinMaxValues(); if (not min or not max) then return; end
	local step=slider:GetValueStep(); if (not step) then return; end
	local value=slider:GetValue(); if (not value) then return; end
	if (arg1==1 and (value-step)>=min) then slider:SetValue(value-step);
	elseif (arg1==-1 and (value+step)<=max) then slider:SetValue(value+step); end
end

-- Some helpers to get past later updates to the WoW code
function DuckWidget.SetButtonText(button,text)
	getglobal(button:GetName().."Text"):SetText(text);
end
function DuckWidget.GetButtonText(button,text)
	return getglobal(button:GetName().."Text"):GetText(text);
end
function DuckWidget.SetButtonTextColor(button,r,g,b,a)
	getglobal(button:GetName().."Text"):SetTextColor(r,g,b,a);
end

-- CheckBox
function DuckWidget.CheckBox.SetIcon(button,image)
	_G[button:GetName().."IconTexture"]:SetTexture(image);
end

-- ListBox
function DuckWidget.ListBox.VisibleEntries(frame)
	local fHeight=frame:GetHeight();
	if (not _G[frame:GetName().."_Entry1"]) then return 1; end
	local eHeight=_G[frame:GetName().."_Entry1"]:GetHeight();
	return math.floor((fHeight+2)/(eHeight+2));
end

function DuckWidget.ListBox.Clear(frame)
	frame.DMEntries=0;
	DuckWidget.ListBox.Redraw(frame);
end

-- Add an entry to the list
-- self    : The frame
-- entry   : Text of the entry to add
-- state   : LIST, checked, unchecked, inactive
-- position: END, number
function DuckWidget.ListBox.Add(frame,entry,state,position,indent,icon,click)
	frame.DMEntries=frame.DMEntries+1;									-- One more in list
	local length=(frame.DMEntries-DuckWidget.ListBox.VisibleEntries(frame))+1;
	if (length<1) then length=1; end
	local _,cur=_G[frame:GetName().."_Scroll"]:GetMinMaxValues();	-- Get span
	if (cur~=length) then
		_G[frame:GetName().."_Scroll"]:SetMinMaxValues(1,length);		-- Set span
	end
	if (not position) then position=frame.DMEntries; end	-- Position not provided, so add at the end
	local i=frame.DMEntries;								-- Make room for it if it's not appended
	while(i>position) do frame.DMTheList[i]=frame.DMTheList[i-1]; i=i-1; end
	return DuckWidget.ListBox.Set(frame,entry,state,position,indent,icon,click);	-- Change it to the supplied info
end

-- Change an entry in the list
-- self    : The frame
-- entry   : Text of the entry to add
-- state   : LIST, checked, unchecked, inactive
-- position: END, number
function DuckWidget.ListBox.Set(frame,entry,state,position,indent,icon,click)
	if (not position) then return DuckWidget.ListBox.Add(frame,entry,state,position,indent,icon,click); end
	if (not frame.DMTheList) then frame.DMTheList={}; end
	frame.DMTheList[position]={
		Entry=entry,
		State=state,
		Tooltip=nil,
		Indent=indent,
		Icon=icon,
		Click=click,
		DB={},
	};

	-- Sort list
	if (frame.defaultSort) then
		position=DuckWidget.ListBox.Sort(frame.DMTheList,frame.DMEntries,position);
	end
--	if (frame.defaultSort and frame.DMEntries>1) then
--		local i=1;
--		while(i<frame.DMEntries) do
--			if (frame.DMTheList[i].Entry>frame.DMTheList[i+1].Entry) then
--				frame.DMTheList[i],frame.DMTheList[i+1]=frame.DMTheList[i+1],frame.DMTheList[i];
--				i=i-2;
--				if (i<0) then i=0; end
--			end
--			i=i+1
--		end
--	end

	DuckWidget.ListBox.Redraw(frame);
	return frame.DMTheList[position];
end

function DuckWidget.ListBox.Sort(list,length,index)
	indent=list[index].Indent;		-- This level
	-- Up
	while(index>1 and list[index-1].Indent==indent and list[index].Entry<list[index-1].Entry) do
		list[index-1],list[index]=list[index],list[index-1];
		index=index-1;
	end
	-- Down
	while(index<length and list[index+1].Indent==indent and list[index].Entry>list[index+1].Entry) do
		list[index+1],list[index]=list[index],list[index+1];
		index=index+1;
	end

	return index;
end

function DuckWidget.ListBox.Redraw(frame)
	if (frame.DMEntries==nil) then return; end
	if (not frame.DMTheList) then frame.DMTheList={}; end				-- No list
	local i;
	local visible=DuckWidget.ListBox.VisibleEntries(frame);
	local fName=frame:GetName();

	-- Visible area not populated by buttons, so create all buttons
	if (not _G[fName.."_Entry"..visible]) then
		-- Create all buttons
		i=2;
		while (i<=visible) do
			if (not _G[fName.."_Entry"..i]) then
				button=CreateFrame("CheckButton",fName.."_Entry"..i,frame,"DuckMod_CheckBoxA_01");
				button:SetPoint("TOPLEFT",_G[fName.."_Entry"..(i-1)],"BOTTOMLEFT",0,-2);
				button:SetPoint("RIGHT",_G[fName.."_Entry"..(i-1)],"RIGHT");
				button:Hide();
			end
			i=i+1;
		end
	end
	local offset=_G[fName.."_Scroll"]:GetValue()-1;
	i=1;
	while(i<=visible and i<=frame.DMEntries-offset) do
		local button=_G[fName.."_Entry"..i];
		if (frame.DMTheList[i+offset]) then
			local text=frame.DMTheList[i+offset].Entry;
			if (text) then
				local indent=frame.DMTheList[i+offset].Indent; if (not indent) then indent=0; end
				indent=button.defaultIndent*(indent+1);
				_G[button:GetName().."Text"]:SetPoint("LEFT","$parent","LEFT",indent,0);
				button:SetText(text);
				button:SetIcon(frame.DMTheList[i+offset].Icon);
				button:Show();
			else
				button:Hide();
			end
		else
			button:Hide();
		end
		i=i+1;
	end
	while(i<=visible) do
		_G[fName.."_Entry"..i]:Hide();			-- Hide unused buttons
		i=i+1;
	end
end

function DuckWidget.ListBox.SliderChanged(frame)
	DuckWidget.ListBox.Redraw(frame);
end

function DuckWidget.ListBox.SetSelectionChanged(self,func)
	this.DM.SelectionChanged=func;
end

function DuckWidget.ListBox.SendEvent(button,event)
	local handler=button:GetParent():GetScript("OnEvent");
	if (not handler) then return; end

	local index=tonumber(button:GetName():sub(button:GetName():find("%d+$")));	-- Last number in name
	index=(index-1)+_G[button:GetParent():GetName().."_Scroll"]:GetValue();	-- Button -> contents
--	DEFAULT_CHAT_FRAME:AddMessage(index,1,0,0);
	arg1=button:GetParent();	-- until cataclysm
	arg2=index;					-- until cataclysm
	handler(this,event,button:GetParent(),index);
end

function DuckWidget.ListBox.ListButtonClicked(button)
	local _,i=button:GetName():find("_Entry");
	if (not i) then return; end
	i=tonumber(button:GetName():sub(i+1));
	local state=button:GetParent().DMTheList[i].State;
	if (state==DM_STATE_INACTIVE) then button:SetChecked(nil);
	elseif (state==DM_STATE_CHECKED) then button:SetChecked(true);
	elseif (state==DM_STATE_UNCHECKED) then button:SetChecked(nil);
	else button:SetChecked(nil);
	end
	DuckWidget.ListBox.SendEvent(button,"DMEVENT_LISTBOX_ITEM_CLICKED");
end

function DuckWidget.ListBox.ListButtonHover(button,enter)
	local event="DMEVENT_LISTBOX_ITEM_";
	if (enter) then event=event.."ENTER"; else event=event.."LEAVE"; end
	DuckWidget.ListBox.SendEvent(button,event);
end

function DuckWidget.ListBox.SetFuncs(frame)
	frame.DMSetSelectionChanged=DuckWidget.ListBox.SetSelectionChanged;
	frame.DMAdd=DuckWidget.ListBox.Add;
	frame.DMSet=DuckWidget.ListBox.Set;
	frame.DMClear=DuckWidget.ListBox.Clear;
end

--[[
	A checklist's custom functions:

	MyCheckList:DMSetSelectionChanged(func)
	- func:	This function will be called when the list's selection
			changes. The parameters are:
			func(frame,index,title,state)
				frame: The list's internal identifier
				index: The list-index of the new selection
				title: The text of the new selection
				state: "true" if checked, "false" if not
]]


end		-- DuckMod_Widgets_Version < this version
