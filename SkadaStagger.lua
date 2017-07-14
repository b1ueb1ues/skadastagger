local Skada = Skada
--local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local mod = Skada:NewModule("Stagger")
local modDetails = Skada:NewModule("Stagger details")

local debug = nil
local function printdebug(...)
   --   print(...)
end
local function debugprint(...)
    --  print(...)
end


local lang='en'
local labels={
}
if lang == 'zh' then
    labels.stin = '醉拳吸收'
    labels.taken = '醉拳承受'
    labels.pb = '活血酒'
    labels.pb_a = '活血酒(平均)'
    labels.qs = '迅饮'
    labels.others = "其他(脱战, t20, 醉拳池中, ...)"
    labels.duration = "醉拳时间"
    labels.freeze = "锁定时间"
    labels.tickmax = "最高醉拳伤害"
elseif lang == 'en' then
    labels.stin = "Damage Staggered"
    labels.taken = "Taken"
    labels.pb = "Purified_brew"
    labels.pb_a = "Purified_brew (average)"
    labels.qs = "Purified_quicksip"
    labels.others = "others(leave combat, tier20, staggering, ...)"
    labels.duration = "Stagger Duration"
    labels.freeze = "Freeze Duration"
    labels.tickmax = "Tick (max)"
end

local function printspell(i,onespell)
    if onespell then
	print(i,onespell[1],onespell[2])
    else
	print('{}')
    end

end

local function getSetDuration(set)
      if set.time > 0 then
            return set.time
      else
            local endtime = set.endtime
            if not endtime then
                  endtime = time()
            end
            return endtime - set.starttime
      end
end

local function nextDataset(win, context)
      context.index = context.index or 1

      local dataset = win.dataset[context.index] or {}
      dataset.id = context.index
      win.dataset[context.index] = dataset

      context.index = context.index + 1
      return dataset
end

local function calcrate(stvar,realst)

    local pbratelist = {0.40,0.41,0.42,0.43,0.44,0.45,0.46,0.47,0.60,0.61,0.62,0.63,0.64,0.65,0.66,0.67}
    local qsratelist = {0,0.05}

    local useisb = 0
    local usepb = 0

    local prate = -1
    local qsrate = -1
    local pamounts = {}
    local qsamounts = {}
    local pamounts_tmp = {}
    local qsamounts_tmp = {}
    local pamount = 0
    local qsamount = 0

    local found = 0

    debugprint('emust',stvar.stpool,'realst',realst)
    if debug then
	table.foreach(stvar.spellhistory,printspell)
    end
    for pflag,pr in ipairs(pbratelist) do 
	if found >= 1 then
	    break
	end
	for iflag,ir in ipairs(qsratelist) do
	    testst = stvar.stpool
	    pamounts = {}
	    qsamounts = {}
	    for sflag,spell in ipairs(stvar.spellhistory) do
		spellname = spell[1]
		--print (spellname)
		if spellname == 'pb' then
		    --print('calc pb stb4',testst)
		    pamount = testst*pr
		    table.insert(pamounts,pamount)
		    testst = testst - pamount
		    --print('calc pb stafter',testst)
		    usepb = 1
		elseif spellname == 'isb' then
		    qsamount= testst*ir
		    table.insert(qsamounts,qsamount)
		    testst = testst - qsamount
		    useisb = 1
		elseif spellname == 'stin' then
		    testst = testst + spell[2]
		elseif spellname == 'stout' then
		    testst = testst - spell[2]
		end
	    end
	    --print ('pr,ir,emust,unitst',pr,ir,testst,realst)
	    if testst-realst< 2 and testst-realst>-2 then 
		found = found + 1
		--qsamounts = qsamounts_tmp
		--pamounts =  pamounts_tmp
		qsrate = ir
		prate = pr
		break
	    end
	end
    end

    if found == 0 then
	--print('404notfound','stpool',stvar.stpool,'realst',realst)
	usepb=0
	useisb=0
	pamounts={}
	qsamounts={}
    end
    if found ~= 0 then
	if usepb ~= 0 then
	    stvar.pbrate = prate
	    if debug then
		print('found:pb pr',prate)
	    end
	end
	if useisb ~= 0 then
	    stvar.qsrate = qsrate
	    if debug then
		print('found:isb qsr',qsrate)
	    end
	    --[[
	    for i,pair in ipairs(qsamounts) do
		table.insert(stvar.qsamounts,pair)
	    end
	    --]]
	end
    end
    return usepb,useisb,pamounts,qsamounts,found
end

local tick = {}
local function logStaggerTick(set, tick, isCurrent)
      local player = Skada:get_player(set, tick.dstGUID, tick.dstName)
      if player then
            player.stagger.taken = player.stagger.taken + tick.samount
            player.stagger.tickCount = player.stagger.tickCount + 1
            if player.stagger.tickMax < tick.samount then
                  player.stagger.tickMax = tick.samount
            end
            if isCurrent then
                  if player.stagger.lastTickTime then
                        local timeSinceLastTick = tick.timestamp - player.stagger.lastTickTime
                        player.stagger.duration = player.stagger.duration + timeSinceLastTick
                        if timeSinceLastTick > 60 then
                              printdebug(tick.dstName.."'s time since last tick: "..timeSinceLastTick.." (ignored)")
                        elseif timeSinceLastTick > 2 then
                              printdebug(tick.dstName.."'s time since last tick: "..timeSinceLastTick)
                              player.stagger.freezeDuration = player.stagger.freezeDuration + (timeSinceLastTick - 0.5)
                        end
                  end
                  if tick.remainingStagger > 0 then
                        player.stagger.lastTickTime = tick.timestamp
                        --printdebug(tick.dstName.."'s stagger tick for "..tick.samount.." ("..tick.remainingStagger.." remains)")
                  else
                        player.stagger.lastTickTime = nil
                        printdebug(tick.dstName.."'s stagger ended")
                  end
            end
      end
end

local purify = {}
local function logStaggerPurify(set, purify)
      local player = Skada:get_player(set, purify.srcGUID, purify.srcName)
      if player then
	  debugprint('>>logstpury',purify.samount)
            player.stagger.purified = player.stagger.purified + purify.samount
            player.stagger.purifyCount = player.stagger.purifyCount + 1
            if player.stagger.purifyMax < purify.samount then
                  player.stagger.purifyMax = purify.samount
            end
      end
end

local function logStaggerQuicksip(set, purify)
      local player = Skada:get_player(set, purify.srcGUID, purify.srcName)
      if player then
            player.stagger.purified_quicksip = player.stagger.purified_quicksip + purify.samount
      end
end

local function logspelllist(stvar,srcGUID,srcName)
    --table.foreach(stvar.spellhistory, printspell) 
    testst = stvar.stpool
    pamount = 0
    qsamount = 0
    pr = stvar.pbrate
    ir = stvar.qsrate
    --table.foreach(stvar.spellhistory, print)
    for sflag,spell in ipairs(stvar.spellhistory) do
	spellname = spell[1]
	if spellname == 'pb' then
	    pamount = testst*pr
	    testst = testst - pamount
	    local purify = {}
	    purify.srcGUID = srcGUID
	    purify.srcName = srcName
	    purify.samount = pamount
	    logStaggerPurify(Skada.current, purify)
	    logStaggerPurify(Skada.total, purify)
	elseif spellname == 'isb' then
	    qsamount = testst*ir
	    local purify = {}
	    purify.srcGUID = srcGUID
	    purify.srcName = srcName
	    purify.samount = qsamount
	    logStaggerQuicksip(Skada.current, purify)
	    logStaggerQuicksip(Skada.total, purify)
	elseif spellname == 'stin' then
	    testst = testst + spell[2]
	elseif spellname == 'stout' then
	    testst = testst - spell[2]
	end
    end

    --[[
    if pamount ~= 0 then
	local purify = {}
	purify.srcGUID = srcGUID
	purify.srcName = srcName
	purify.samount = pamount
	logStaggerPurify(Skada.current, purify)
	logStaggerPurify(Skada.total, purify)
    end
    if qsamount ~= 0 then
	local purify = {}
	purify.srcGUID = srcGUID
	purify.srcName = srcName
	purify.samount = qsamount
	logStaggerQuicksip(Skada.current, purify)
	logStaggerQuicksip(Skada.total, purify)
    end
    --]]
end


local function proc_st_tick(timestamp,dstGUID,dstName,samount,sabsorbed,srcName,srcGUID,isabsorb)
    local player = Skada:get_player(Skada.current, dstGUID, dstName)
    stvar = player.stagger
    tick.timestamp = timestamp
    tick.dstGUID = dstGUID
    tick.dstName = dstName
    tick.samount = samount
    tick.remainingStagger = UnitStagger(dstName)
    --print(samount,sabsorbed,sschool)
    logStaggerTick(Skada.current, tick, true)
    logStaggerTick(Skada.total, tick, false)


    if sabsorbed then
	if player.stagger.tickMax < samount+sabsorbed then
	      player.stagger.tickMax = samount+sabsorbed
	end
	playertotal = Skada:get_player(Skada.total, dstGUID, dstName)
	if playertotal.stagger.tickMax < samount+sabsorbed then
	      playertotal.stagger.tickMax = samount+sabsorbed
	end
    end


    local unitst = UnitStagger(srcName) 
    if debug then
	print ('--stdmg',samount,'stpool',stvar.stpool,'unitst:',unitst)
    end

    if stvar.spellhistory[1] ~= nil then
	if stvar.spellhistory[1][1] == 'stin' and stvar.spellhistory[2] == nil then
	    local donothing = nil
	elseif stvar.spellhistory[1][1] == 'stout' and stvar.spellhistory[2] == nil then
	    local donothing = nil
	elseif stvar.spellhistory[1][1] == 'stin' and stvar.spellhistory[2][1] == 'stout' and stvar.spellhistory[3]==nil then
	    local donothing = nil
	else

	    --if debug then
	    --    table.foreach(stvar.spellhistory, printspell) 
	    --end

	    if stvar.pbrate == -1 or stvar.qsrate == -1 then
		if debug then
		    print('calcrate')
		end
		local realst = 0
		if sabsorbed then
		    realst = unitst+samount+sabsorbed
		else
		    realst = unitst+samount
		end
		usepb,useisb,pamounts,qsamounts,found = calcrate(stvar,realst)	
		if found == 0 and isabsorb == 1 then
		    return
		end
		if usepb == 1 then
		    --print(stvar.pamounts[1],stvar.pamounts[2])
		    for i, pamount in ipairs(pamounts) do
			local purify = {}
			purify.srcGUID = srcGUID
			purify.srcName = srcName
			purify.samount = pamount
			logStaggerPurify(Skada.current, purify)
			logStaggerPurify(Skada.total, purify)
		    end
		end
		if useisb == 1 then
		    for i, qsamount in ipairs(qsamounts) do
			local purify = {}
			purify.srcGUID = srcGUID
			purify.srcName = srcName
			purify.samount = qsamount
			logStaggerQuicksip(Skada.current, purify)
			logStaggerQuicksip(Skada.total, purify)
		    end
		end

	    else
		if debug then
		    print('rate:',stvar.pbrate,stvar.qsrate)
		end
		logspelllist(stvar,srcGUID,srcName)
	    end
	end
    end
	stvar.stpool = unitst
--	if debug then
--	    stvar.stpool_static = unitst
--	end
	stvar.spellhistory = {}
	sttaken = sttaken + samount
end



--[[
local logStaggerPurify_static = nil
local logStaggerQuicksip_static = nil
if debug then
    logStaggerPurify_static = function(set, purify)
	  local player = Skada:get_player(set, purify.srcGUID, purify.srcName)
	  if player then
	      debugprint('>>logstpury_static',purify.samount)
		player.stagger.purified_static = player.stagger.purified_static + purify.samount
		--player.stagger.purifyCount = player.stagger.purifyCount + 1
	  end
    end
    logStaggerQuicksip_static = function(set, purify)
	  local player = Skada:get_player(set, purify.srcGUID, purify.srcName)
	  if player then
		player.stagger.purified_quicksip_static = player.stagger.purified_quicksip_static + purify.samount
	  end
    end
end
--]]


local function log_stabsorb(set,samount, dstGUID, dstName)
	-- Stagger absorbs
	local player = Skada:get_player(set, dstGUID, dstName)
	player.stagger.absorbed = player.stagger.absorbed + samount


	if set == Skada.current then
	    local stvar = player.stagger
	    --[[
	    if debug then
		stvar.stpool_static = stvar.stpool_static + samount
	    end
	    --]]
	    table.insert(stvar.spellhistory, {'stin',samount})
	    if debug then
		print('--absorb',samount,'stpoolb4',stvar.stpool,'unitst',UnitStagger(dstName))
	    end
	end
end

local tick = {}
local function SpellAbsorbed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local chk = ...
    local spellId, spellName, spellSchool, aGUID, aName, aFlags, aRaidFlags, aspellId, aspellName, aspellSchool, aAmount

    if type(chk) == "number" then
	-- Spell event
	spellId, spellName, spellSchool, aGUID, aName, aFlags, aRaidFlags, aspellId, aspellName, aspellSchool, aAmount = ...
	--print(spellId,spellName,aspellId,aspellName)

	if spellId == 124255 then
	--if nil then
	    if debug then
		print('st absorbed','aAmount',aAmount)
	    end

	    proc_st_tick(timestamp,dstGUID,dstName,aAmount,0,srcName,srcGUID,1)

	    --[[
	    tick.timestamp = timestamp
	    tick.dstGUID = dstGUID
	    tick.dstName = dstName
	    tick.samount = aAmount
	    tick.remainingStagger = UnitStagger(dstName)
	    logStaggerTick(Skada.current, tick, true)
	    logStaggerTick(Skada.total, tick, false)

	    local player = Skada:get_player(Skada.current, dstGUID, dstName)
	    table.insert(player.stagger.spellhistory, {'stout',aAmount})
		--]]

	end

	if aspellId ~= 115069 then
	    return
	end
	if aAmount then
	    log_stabsorb(Skada.current, aAmount,  dstGUID, dstName)
	    log_stabsorb(Skada.total, aAmount, dstGUID, dstName)
	end
    else
	-- Swing event
	aGUID, aName, aFlags, aRaidFlags, aspellId, aspellName, aspellSchool, aAmount = ...


	if aspellId ~= 115069 then
	    return
	end
	if aAmount then
	    log_stabsorb(Skada.current, aAmount, dstGUID, dstName)
	    log_stabsorb(Skada.total, aAmount, dstGUID, dstName)
	end
    end
end

last = 0
sttaken = 0



local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellId, spellName, spellSchool, samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...


    if spellId == 124255 then -- Stagger damage
	proc_st_tick(timestamp,dstGUID,dstName,samount,sabsorbed,srcName,srcGUID)
    end
end

stpury = 0
local function SpellCast(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellId, spellName, spellSchool = ...
    local player = Skada:get_player(Skada.current, srcGUID, srcName)
    local stvar = player.stagger
    if spellId == 119582 then -- Purifying brew
	table.insert(stvar.spellhistory,{'pb',1})
--	if debug then
--	    print('cast pb','stpool',player.stagger.stpool,'unitst',UnitStagger(srcName))
--	    local purifiedAmount =  stvar.stpool_static * 0.64
--	    local purify = {}
--	    purify.srcGUID = srcGUID
--	    purify.srcName = srcName
--	    purify.samount = purifiedAmount
--	    logStaggerPurify_static(Skada.current, purify)
--	    logStaggerPurify_static(Skada.total, purify)
--	end
    elseif spellId == 115308 then
	table.insert(stvar.spellhistory,{'isb',1})
--	if debug then
--	    print('cast isb','stpool',player.stagger.stpool,'unitst',UnitStagger(srcName))
--	    local purifiedAmount =  stvar.stpool_static * 0.05
--	    --stvar.stpool = stvar.stpool * 0.95
--	    purify.srcGUID = srcGUID
--	    purify.srcName = srcName
--	    purify.samount = purifiedAmount
--	    logStaggerQuicksip_static(Skada.current, purify)
--	    logStaggerQuicksip_static(Skada.total, purify)
--	end
    end
end

function mod:OnEnable()
      mod.metadata = {showspots = false, click1 = modDetails}
      modDetails.metadata = {showspots = false, ordersort = true}
      
      Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {src_is_interesting = true, dst_is_interesting_nopets = false})
      Skada:RegisterForCL(SpellCast, 'SPELL_CAST_SUCCESS', {src_is_interesting = true, dst_is_interesting_nopets = false})
      Skada:RegisterForCL(SpellAbsorbed, 'SPELL_ABSORBED', {dst_is_interesting = true})

      Skada:AddMode(self, "Stagger")
end

function mod:OnDisable()
      Skada:RemoveMode(self)
end

function modDetails:Enter(win, id, label)
      modDetails.playerid = id
      modDetails.title = label.."'s Stagger"
end

function modDetails:Update(win, set)
      local player = Skada:find_player(set, self.playerid)
      if player then
            local playerStagger = player.stagger
            local staggerabsorbed = playerStagger.absorbed
	    local damageStaggered = staggerabsorbed
            if damageStaggered == 0 then
                  return
            end

            local setDuration = getSetDuration(set)
            local datasetContext = {}

            --local staggerabsorb = nextDataset(win, datasetContext)
            --staggerabsorb.label = "Staggered absorbed"
            --staggerabsorb.valuetext = Skada:FormatNumber(staggerabsorbed)
            --staggerabsorb.value = 1



	    -- dmg staggered
            local staggered = nextDataset(win, datasetContext)
            staggered.label = labels.stin
            staggered.valuetext = Skada:FormatNumber(damageStaggered)
            staggered.value = 1


	    -- stagger taken
            local staggerTaken = nextDataset(win, datasetContext)
            staggerTaken.label = labels.taken
            staggerTaken.valuetext = Skada:FormatNumber(playerStagger.taken)..(" (%02.1f%%)"):format(playerStagger.taken / damageStaggered * 100)
            staggerTaken.value = playerStagger.taken / damageStaggered


	    -- purifying brew
            if playerStagger.purifyCount > 0 then
                  local staggerPurified = nextDataset(win, datasetContext)
                  staggerPurified.label = labels.pb
                  staggerPurified.valuetext = Skada:FormatNumber(playerStagger.purified)..(" (%02.1f%%)"):format(playerStagger.purified / damageStaggered * 100)
                  staggerPurified.value = playerStagger.purified / damageStaggered


		  -- purifying brew ave
                  local staggerPurifiedAvg = nextDataset(win, datasetContext)
                  staggerPurifiedAvg.label = labels.pb_a
                  staggerPurifiedAvg.valuetext = Skada:FormatNumber(playerStagger.purified / playerStagger.purifyCount).." ("..playerStagger.purifyCount.."x)"
                  staggerPurifiedAvg.value = (playerStagger.purified / playerStagger.purifyCount) / damageStaggered
            end

	    --[[
	    if debug then
		if playerStagger.purifyCount > 0 then
		      local staggerPurified_s = nextDataset(win, datasetContext)
		      staggerPurified_s.label = "Purified_brew_static"
		      staggerPurified_s.valuetext = Skada:FormatNumber(playerStagger.purified_static)..(" (%02.1f%%)"):format(playerStagger.purified_static / damageStaggered * 100)
		      staggerPurified_s.value = playerStagger.purified_static / damageStaggered

		end
		if playerStagger.purified_quicksip_static > 0 then
		    local staggerquicksip_s = nextDataset(win, datasetContext)
		    staggerquicksip_s.label = "Purified_quicksip_static"
		    staggerquicksip_s.valuetext = Skada:FormatNumber(playerStagger.purified_quicksip_static)..(" (%02.1f%%)"):format(playerStagger.purified_quicksip_static / damageStaggered * 100)
		    staggerquicksip_s.value = playerStagger.purified_quicksip_static / damageStaggered
		end
	    end
	    --]]

	    -- quicksip
	    if playerStagger.purified_quicksip > 0 then
		local staggerquicksip = nextDataset(win, datasetContext)
		staggerquicksip.label = labels.qs
		staggerquicksip.valuetext = Skada:FormatNumber(playerStagger.purified_quicksip)..(" (%02.1f%%)"):format(playerStagger.purified_quicksip / damageStaggered * 100)
		staggerquicksip.value = playerStagger.purified_quicksip / damageStaggered
	    end

	    -- others
	    local others = damageStaggered - playerStagger.taken - playerStagger.purified - playerStagger.purified_quicksip


	    if others >= 0 then
		local o = nextDataset(win, datasetContext)
		o.label = labels.others
		o.valuetext = Skada:FormatNumber(others)..(" (%02.1f%%)"):format(others / damageStaggered * 100)
		o.value = others / damageStaggered
	    end

	    -- duration
            if setDuration > 0 and playerStagger.duration > 0 then
                  local staggerDuration = nextDataset(win, datasetContext)
                  staggerDuration.label = labels.duration
                  staggerDuration.valuetext = ("%02.1fs"):format(playerStagger.duration)
                  staggerDuration.value = playerStagger.duration / setDuration
                  
		  -- freeze
                  if playerStagger.freezeDuration > 2 then
                        local freezeDuration = nextDataset(win, datasetContext)
                        freezeDuration.label = labels.freeze
                        freezeDuration.valuetext = ("%02.1fs"):format(playerStagger.freezeDuration)..(" (%02.1f%%)"):format(playerStagger.freezeDuration / playerStagger.duration * 100)
                        freezeDuration.value = playerStagger.freezeDuration / setDuration
                  end
            end

	    -- tick max
            local tickMax = nextDataset(win, datasetContext)
            tickMax.label = labels.tickmax
            tickMax.valuetext = Skada:FormatNumber(playerStagger.tickMax)
            tickMax.value = playerStagger.tickMax / damageStaggered

	    -- statistical error
	    if debug then 
		local er = nextDataset(win, datasetContext)
		er.label = 'debug use statistical err'
		evalue = damageStaggered - playerStagger.taken - playerStagger.purified - playerStagger.purified_quicksip
		evaluepercent = evalue / damageStaggered
		er.valuetext = ''..evalue
		er.value = playerStagger.tickMax / damageStaggered
	    end

            win.metadata.maxvalue = 1
	    
      end
end

function mod:AddPlayerAttributes(player, set)
      if not player.stagger then
            player.stagger = 
            {
		  purified_quicksip = 0,
		  purified_quicksip_static = 0,

		  absorbed = 0,
		  dtb4st = 0,
		  stpool = 0,
		  stpool_static = 0,
		
		  t20 = -1,
		  qsrate = -1,
		  pbrate = -1,
		  spellhistory = {},

                  taken = 0,
                  purified = 0,
                  purified_static = 0,
                  purifyCount = 0,
                  purifyMax = 0,


                  lastTickTime = nil,
                  tickMax = 0,
                  tickCount = 0,

                  duration = 0,
                  freezeDuration = 0,
            }
      end          
end

function mod:GetSetSummary(set)
      local totalPurified = 0
      for i, player in ipairs(set.players) do
            if player.stagger then
                  totalPurified = totalPurified + player.stagger.purified
            end
      end
      return "(purified) "..Skada:FormatNumber(totalPurified)
end

function mod:Update(win, set)
      local nr = 1
      local max = 0

      for i, player in ipairs(set.players) do
            if player.stagger then

                  local value = player.stagger.absorbed
                  if value > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = player.id
                        d.label = player.name
                        d.value = value
                        d.valuetext = Skada:FormatNumber(value)
                        d.class = player.class
                        d.role = player.role

                        if max < value then
                              max = value
                        end
                  end
                  nr = nr + 1
            end
      end
      win.metadata.maxvalue = max
end
