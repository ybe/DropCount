--[[
------------------------------------------------------------------------
	ListBox:DMAdd(entry [,state [,indent [,icon] ] ] )
		Add entry to the end of the list
	ListBox:DMSet(entry [,state [,indent [,icon [,position] ] ] ] )
		Set/change an existing entry

	entry   : Visible text
	state   : DM_STATE_LIST|DM_STATE_INACTIVE|DM_STATE_CHECKED|DM_STATE_UNCHECKED
	indent  : 0|1|2...
	icon    : file-name
	position: Index in list to change

------------------------------------------------------------------------
	ListBox:DMClear()
	
	Clear the list.

------------------------------------------------------------------------
	Events

	The events are sent to the ListBox parent with these parameters,
	excluding the hidden "self":
		1: Handle of the list-item widget
		2: Event (as listed below)
		3: Handle of the ListBox frame
		4: The index-number the clicked item represents in the list


	DMEVENT_LISTBOX_ITEM_CLICKED
		Sent when a list-item has been clicked
	DMEVENT_LISTBOX_ITEM_ENTER/LEAVE
		Sent when the mouse enters/leaves a list-item

------------------------------------------------------------------------
	XML usage

	<Frame name="$parent_ListBox" inherits="DuckMod_ListBox_01">
		<Size><AbsDimension x="245" y="109"/></Size>
		<Anchors>
			<Anchor point="TOPLEFT"><Offset><AbsDimension x="11" y="-125" /></Offset></Anchor>
		</Anchors>
	</Frame>

------------------------------------------------------------------------
	Lua usage

	The ListBox's parent needs an OnEvent handler, which will be called
	with the above mentioned events.


========================================================================
========================================================================
IMPORTANT
========================================================================
The following scripts are reserved for the ListBox widget. If you
desperately need some of these, hook them in Lua in stead of defining
them in XML.
	OnLoad
	OnMouseWheel
	OnScrollRangeChanged
========================================================================
]]


if (not DuckMod_Widgets_Version) then
	DuckMod_Widgets_Version=0;
end


if (DuckMod_Widgets_Version<1) then				-- This version
	DuckMod_Widgets_Version=1;

	DM_STATE_LIST=0;			-- Just dumb text
	DM_STATE_INACTIVE=1;		-- Unclickable button
	DM_STATE_CHECKED=2;			-- Checked button
	DM_STATE_UNCHECKED=3;		-- Unchecked button

	if (not DuckWidget) then DuckWidget={}; end	-- If it exists, just overlay
	if (not DuckWidget.ListBox) then DuckWidget.ListBox={}; end	-- If it exists, just overlay
	if (not DuckWidget.CheckBox) then DuckWidget.CheckBox={}; end	-- If it exists, just overlay


function DuckWidget:CopyTable(t)
	if (not t) then return nil; end
	local new={};
	local i,v;
	for i,v in pairs(t) do
		if (type(v)=="table") then new[i]=self:CopyTable(v); else new[i]=v; end
	end
	return new;
end


-- Generic mouse-wheel handler for scrolling-panes.
-- o The main use for this is when a pane has other items in it that
--   may receive it in stead. They may then call this function with
--   their parent as an argument.
function DuckWidget.MouseWheel(slider,delta)
	if (not slider) then return; end
	local min,max=slider:GetMinMaxValues(); if (not min or not max) then return; end
	local step=slider:GetValueStep(); if (not step) then return; end
	local value=slider:GetValue(); if (not value) then return; end
	if (delta==1 and (value-step)>=min) then slider:SetValue(value-step);
	elseif (delta==-1 and (value+step)<=max) then slider:SetValue(value+step); end
end

-- Some helpers to get past later updates to the WoW code
function DuckWidget.CheckBox.SetButtonText(button,text)
	_G[button:GetName().."Text"]:SetText(text);
end
function DuckWidget.CheckBox.GetButtonText(button)
	return _G[button:GetName().."Text"]:GetText();
end
function DuckWidget.CheckBox.SetButtonTextColor(button,r,g,b,a)
	_G[button:GetName().."Text"]:SetTextColor(r,g,b,a);
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
	return math.floor((fHeight+frame.DMSpacing)/(eHeight+frame.DMSpacing));
end

function DuckWidget.ListBox.Clear(frame)
	frame.DMEntries=0;
	DuckWidget.ListBox.Redraw(frame);
end

-- Add an entry to the list
-- self    : The frame
-- entry   : Text of the entry to add
-- state   : LIST, checked, unchecked, inactive
-- position: END, index
function DuckWidget.ListBox.Add(frame,entry,state,indent,icon)
	local position=nil;
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
	return DuckWidget.ListBox.Set(frame,entry,state,indent,icon,position);	-- Change it to the supplied info
end

-- Change an entry in the list
-- self    : The frame
-- entry   : Text of the entry to set
-- state   : LIST, checked, unchecked, inactive
-- position: END, index
function DuckWidget.ListBox.Set(frame,entry,state,indent,icon,position)
	if (not position) then return DuckWidget.ListBox.Add(frame,entry,state,indent,icon); end
	if (not frame.DMTheList) then frame.DMTheList={}; end
	if (not state) then state=DM_STATE_LIST; end
	if (not indent) then indent=0; end

	frame.DMTheList[position]={
		Entry=entry,
		State=state,
		Tooltip=nil,
		Indent=indent,
		Icon=icon,
		DB={},
	};

	if (frame.defaultSort) then
		position=DuckWidget.ListBox.Sort(frame.DMTheList,frame.DMEntries,position);
	end

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

--function DuckWidget.ListBox.GetData(frame,index)
--	return frame.DMTheList[index].DB;
--end

--function DuckWidget.ListBox.SetData(frame,index,entry,value)
--	frame.DMTheList[index].DB[entry]=value;
--end

function DuckWidget.ListBox.Redraw(frame,remake)
	if (frame.DMEntries==nil) then return; end
	if (not frame.DMTheList) then frame.DMTheList={}; end				-- No list
	local i;
	local visible=DuckWidget.ListBox.VisibleEntries(frame);
	local fName=frame:GetName();

	-- Visible area not populated by buttons, so create all buttons
	if (not _G[fName.."_Entry"..visible] or remake) then
		-- Create and place all buttons
		i=2;
		while (i<=visible) do
			local button=_G[fName.."_Entry"..i];
			if (not button) then
				button=CreateFrame("CheckButton",fName.."_Entry"..i,frame,"DuckMod_CheckBoxA_01");
			end
			button:ClearAllPoints();
			button:SetPoint("TOPLEFT",_G[fName.."_Entry"..(i-1)],"BOTTOMLEFT",0,-frame.DMSpacing);
			button:SetPoint("RIGHT",_G[fName.."_Entry"..(i-1)],"RIGHT");
			button:Hide();
			i=i+1;
		end
		while(_G[fName.."_Entry"..i]) do
			_G[fName.."_Entry"..i]:Hide();			-- Hide unused buttons due to size-changes
			i=i+1;
		end
	end

	-- Update from first visible entry
	local offset=_G[fName.."_Scroll"]:GetValue()-1;
	i=1;
	while(i<=visible and i<=frame.DMEntries-offset) do
		local button=_G[fName.."_Entry"..i];
		if (frame.DMTheList[offset+i]) then
			local text=frame.DMTheList[offset+i].Entry;
			if (text) then
				local indent=frame.DMTheList[offset+i].Indent; if (not indent) then indent=0; end
				indent=button.defaultIndent*(indent+1);
				_G[button:GetName().."Text"]:SetPoint("LEFT","$parent","LEFT",indent,0);
				button:SetText(text);
				button:SetIcon(frame.DMTheList[offset+i].Icon);
				button.ListIndex=offset+i;
				if (frame.DMTheList[offset+i].State==DM_STATE_CHECKED) then
					button:SetChecked(true);
				else
					button:SetChecked(nil);
				end
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

function DuckWidget.ListBox.SendEvent(button,event)
	local parent=button:GetParent():GetParent();
	local handler=parent:GetScript("OnEvent");
	if (not handler) then
		parent=button:GetParent();
		handler=parent:GetScript("OnEvent");
		if (not handler) then DEFAULT_CHAT_FRAME:AddMessage("No handler"); return; end
	end
	handler(parent,event,button:GetParent(),button.ListIndex);
end

function DuckWidget.ListBox.ListButtonClicked(button)
	local _,i=button:GetName():find("_Entry"); if (not i) then return; end
	i=tonumber(button:GetName():sub(i+1));
	local state=button:GetParent().DMTheList[i].State;
	if (state==DM_STATE_CHECKED) then state=DM_STATE_UNCHECKED;
	elseif (state==DM_STATE_UNCHECKED) then state=DM_STATE_CHECKED;
	elseif (state==DM_STATE_LIST) then state=DM_STATE_UNCHECKED;
	elseif (state==DM_STATE_INACTIVE) then state=DM_STATE_UNCHECKED;
	end

	-- Set all buttons unchecked
	local tmp=1;
	while (tmp<=button:GetParent().DMEntries) do
		if (button:GetParent().DMTheList[tmp].State==DM_STATE_CHECKED) then
			button:GetParent().DMTheList[tmp].State=DM_STATE_UNCHECKED;
		end
		tmp=tmp+1;
	end
	-- Set correct for this button
	button:GetParent().DMTheList[i].State=state;

	DuckWidget.ListBox.Redraw(button:GetParent());
	DuckWidget.ListBox.SendEvent(button,"DMEVENT_LISTBOX_ITEM_CLICKED");
end

function DuckWidget.ListBox.ListButtonHover(button,enter)
	local event="DMEVENT_LISTBOX_ITEM_";
	if (enter) then event=event.."ENTER"; else event=event.."LEAVE"; end
	DuckWidget.ListBox.SendEvent(button,event);
end

function DuckWidget.ListBox.SetFuncs(frame)
	frame.DMAdd=DuckWidget.ListBox.Add;
	frame.DMSet=DuckWidget.ListBox.Set;
	frame.DMClear=DuckWidget.ListBox.Clear;
	frame.DMUpdate=DuckWidget.ListBox.Redraw;
end


end		-- DuckMod_Widgets_Version < this version
