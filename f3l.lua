-- F3L Training Script (EdgeTX / OpenTX Telemetry Script)
-- Final test version (+ small robustness improvements)
-- Working time:
--  * 1:00 remaining -> voice "1 minute"
--  * 0:30 remaining -> voice "30 seconds"
--  * last 10s -> beep each second (no voice)
-- Flight time:
--  * voice per minute, 30/20s, last 15s spoken numbers
-- SF:
--  * speaks remaining working time in whole seconds
-- Display:
--  * tenths on screen
-- Improvements added now:
--  * Working time end = triple-beep pattern (very distinct)
--  * SA landing sets armLaunch=false to prevent instant re-launch if elevator stays high
--  * resetFlightOnly starts with armLaunch=false (requires elevator dip before next launch)

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local WORKING_TIME = 540
local MAX_FLIGHT   = 360

local ELEV_SOURCE  = "ele"
local ELEV_THRESH  = 80

local SF_SOURCE    = "sf"
local SA_SOURCE    = "sa"

local VOICE_MIN_GAP = 0.7
local BACK_CONFIRM_WINDOW = 2.0
local ENTER_DOUBLE_WINDOW = 1.0

local WORK_BEEP_SUPPRESS_AFTER_SPEECH = 0.9

------------------------------------------------------------
-- State
------------------------------------------------------------
local state = {
  lastFlightDuration = nil,
  lastFlightDurationFloat = nil,

  windowRunning = false,
  windowStart   = 0,

  flightStarted  = false,
  flightStart    = 0,
  flightStartSec = 0,
  flightEnded    = false,
  flightEnd      = 0,

  armLaunch = false,

  sfPrev = false,
  saPrev = 0,

  lastFlightRemMin = nil,
  lastFlightRemSec = nil,

  lastVoiceAt = -9999,
  lastCountdownSpoken = nil,

  -- working warnings
  workSpoke60 = false,
  workSpoke30 = false,
  lastWorkRemSec = nil,
  suppressWorkBeepsUntil = 0,

  backArmedUntil = 0,
  showBackHintUntil = 0,
  enterArmedUntil = 0
}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function nowSeconds()
  return getTime() / 100
end

local function nowIntSeconds()
  return math.floor(nowSeconds() + 0.0001)
end

local function formatTimePrec(sec)
  if sec == nil or sec ~= sec or sec < 0 then sec = 0 end
  local totalTenths = math.floor(sec * 10 + 0.5)
  local tenths = totalTenths % 10
  local secondsWhole = math.floor(totalTenths / 10)
  local m = math.floor(secondsWhole / 60)
  local s = secondsWhole % 60
  return string.format("%02d:%02d.%d", m, s, tenths)
end

local function getElevPercent()
  local v = getValue(ELEV_SOURCE)
  if v == nil then return 0 end
  return v / 10.24
end

local function canSpeak(t)
  return (t - state.lastVoiceAt) >= VOICE_MIN_GAP
end

local function markSpoke(t)
  state.lastVoiceAt = t
  state.suppressWorkBeepsUntil = t + WORK_BEEP_SUPPRESS_AFTER_SPEECH
end

local function hardReset()
  state.lastFlightDuration = nil
  state.lastFlightDurationFloat = nil

  state.windowRunning = false
  state.windowStart   = 0

  state.flightStarted  = false
  state.flightStart    = 0
  state.flightStartSec = 0
  state.flightEnded    = false
  state.flightEnd      = 0

  state.armLaunch = false

  state.lastFlightRemMin = nil
  state.lastFlightRemSec = nil
  state.lastVoiceAt      = -9999
  state.lastCountdownSpoken = nil

  state.workSpoke60 = false
  state.workSpoke30 = false
  state.lastWorkRemSec = nil
  state.suppressWorkBeepsUntil = 0

  state.backArmedUntil    = 0
  state.showBackHintUntil = 0
  state.enterArmedUntil   = 0

  playTone(500, 180, 0, PLAY_BACKGROUND)
end

local function resetFlightOnly()
  state.flightStarted  = false
  state.flightStart    = 0
  state.flightStartSec = 0
  state.flightEnded    = false
  state.flightEnd      = 0

  state.lastFlightDuration = nil
  state.lastFlightDurationFloat = nil

  state.lastFlightRemMin = nil
  state.lastFlightRemSec = nil
  state.lastCountdownSpoken = nil
  state.lastVoiceAt = -9999

  -- Improvement: require elevator dip again before new launch
  state.armLaunch = false

  playTone(1000, 150, 0, PLAY_BACKGROUND)
  playTone(1000, 150, 180, PLAY_BACKGROUND)
end

local function finishFlightAt(t)
  state.flightEnded = true
  state.flightEnd = t
  local durFloat = state.flightEnd - state.flightStart
  if durFloat < 0 then durFloat = 0 end
  state.lastFlightDurationFloat = durFloat
  state.lastFlightDuration = math.floor(durFloat + 0.5)
end

local function getFlightElapsed(t)
  if not state.flightStarted then return 0 end
  if state.flightEnded then
    return state.flightEnd - state.flightStart
  else
    return t - state.flightStart
  end
end

local function getFlightRemaining(t)
  if not state.flightStarted then return MAX_FLIGHT end
  local rem = MAX_FLIGHT - getFlightElapsed(t)
  if rem < 0 then rem = 0 end
  return rem
end

------------------------------------------------------------
-- Working-time alerts
------------------------------------------------------------
local function handleWorkingAlerts(t)
  if not state.windowRunning then
    state.workSpoke60 = false
    state.workSpoke30 = false
    state.lastWorkRemSec = nil
    return
  end

  local remaining = math.floor(WORKING_TIME - (t - state.windowStart) + 0.5)
  if remaining < 0 then remaining = 0 end

  if remaining == 60 and not state.workSpoke60 then
    if canSpeak(t) then
      playDuration(60)
      markSpoke(t)
      state.workSpoke60 = true
    end
    return
  end

  if remaining == 30 and not state.workSpoke30 then
    if canSpeak(t) then
      playDuration(30)
      markSpoke(t)
      state.workSpoke30 = true
    end
    return
  end

  if remaining <= 10 and remaining >= 1 then
    if t < state.suppressWorkBeepsUntil then return end
    if state.lastWorkRemSec == nil or state.lastWorkRemSec ~= remaining then
      playTone(1400, 60, 0, PLAY_BACKGROUND)
      state.lastWorkRemSec = remaining
    end
  end
end

------------------------------------------------------------
-- Input handling
------------------------------------------------------------
local function handleInputs(event)
  local t = nowSeconds()

  if event == EVT_EXIT_BREAK then
    if state.backArmedUntil > t then
      hardReset()
      return
    else
      state.backArmedUntil = t + BACK_CONFIRM_WINDOW
      state.showBackHintUntil = t + BACK_CONFIRM_WINDOW
      playTone(900, 120, 0, PLAY_BACKGROUND)
      return
    end
  end

  if event == EVT_ENTER_BREAK then
    if (not state.windowRunning) and state.windowStart == 0 then
      state.windowRunning = true
      state.windowStart   = t
      state.armLaunch     = true
      state.enterArmedUntil = 0

      state.workSpoke60 = false
      state.workSpoke30 = false
      state.lastWorkRemSec = nil
      state.suppressWorkBeepsUntil = 0

      playTone(1200, 200, 0, PLAY_BACKGROUND)
      return
    end

    if state.windowRunning then
      if state.enterArmedUntil > t then
        resetFlightOnly()
        state.enterArmedUntil = 0
      else
        state.enterArmedUntil = t + ENTER_DOUBLE_WINDOW
        playTone(700, 60, 0, PLAY_BACKGROUND)
      end
    end
  end

  -- SA down = landing: end flight ONLY
  local sa = getValue(SA_SOURCE)
  if sa ~= nil and sa ~= state.saPrev then
    if sa < 0 and state.flightStarted and (not state.flightEnded) then
      finishFlightAt(t)
      playTone(800, 200, 0, PLAY_BACKGROUND)
      -- Improvement: prevent instant re-launch if elevator stays high
      state.armLaunch = false
    end
    state.saPrev = sa
  end

  -- SF momentary = speak remaining working time (integer only)
  local sf = getValue(SF_SOURCE)
  local sfActive = (sf ~= nil and sf < 0)

  if sfActive and (not state.sfPrev) then
    local remaining = WORKING_TIME
    if state.windowRunning then
      remaining = WORKING_TIME - (t - state.windowStart)
    elseif state.windowStart > 0 then
      remaining = 0
    end
    if remaining < 0 then remaining = 0 end

    local remainingSec = math.floor(remaining + 0.5)

    if canSpeak(t) then
      playDuration(remainingSec)
      markSpoke(t)
    end
  end

  state.sfPrev = sfActive
end

------------------------------------------------------------
-- Flight voice cues
------------------------------------------------------------
local function handleFlightVoice(t)
  if not (state.flightStarted and not state.flightEnded) then return end

  local nowSec = nowIntSeconds()
  local elapsedSec = nowSec - state.flightStartSec
  if elapsedSec < 0 then elapsedSec = 0 end

  local remaining = MAX_FLIGHT - elapsedSec

  if remaining <= 0 then
    finishFlightAt(state.flightStart + MAX_FLIGHT)
    playTone(600, 350, 0, PLAY_BACKGROUND)
    return
  end

  local remMin = math.floor(remaining / 60)
  local remSec = remaining % 60

  if remSec == 0 and remMin > 0 and remMin < 6 then
    if state.lastFlightRemMin ~= remMin and canSpeak(t) then
      playDuration(remMin * 60)
      markSpoke(t)
      state.lastFlightRemMin = remMin
    end
  end

  if remMin == 0 and (remaining == 30 or remaining == 20) then
    if state.lastFlightRemSec ~= remaining and canSpeak(t) then
      playDuration(remaining)
      markSpoke(t)
      state.lastFlightRemSec = remaining
    end
  end

  if remaining <= 15 then
    if state.lastCountdownSpoken ~= remaining then
      playNumber(remaining, 0, 0)
      state.lastCountdownSpoken = remaining
    end
  else
    state.lastCountdownSpoken = nil
  end
end

------------------------------------------------------------
-- State update
------------------------------------------------------------
local function updateState()
  local t = nowSeconds()

  if state.backArmedUntil > 0 and t >= state.backArmedUntil then
    state.backArmedUntil = 0
  end

  if state.enterArmedUntil > 0 and t >= state.enterArmedUntil then
    state.enterArmedUntil = 0
  end

  local elev = getElevPercent()

  -- Launch detection
  if state.windowRunning then
    if elev < (ELEV_THRESH - 10) then
      state.armLaunch = true
    end

    if state.armLaunch and (not state.flightStarted) and elev >= ELEV_THRESH then
      state.flightStarted  = true
      state.flightStart    = t
      state.flightStartSec = nowIntSeconds()
      state.flightEnded    = false
      state.flightEnd      = 0
      state.armLaunch      = false

      state.lastFlightRemMin = nil
      state.lastFlightRemSec = nil
      state.lastCountdownSpoken = nil

      playTone(1500, 200, 0, PLAY_BACKGROUND)
    end
  end

  -- Working time expiry
  if state.windowRunning and (t - state.windowStart) >= WORKING_TIME then
    state.windowRunning = false

    -- distinct working time end pattern (triple beep)
    playTone(900, 80, 0, PLAY_BACKGROUND)
    playTone(900, 80, 120, PLAY_BACKGROUND)
    playTone(900, 80, 240, PLAY_BACKGROUND)

    if state.flightStarted and not state.flightEnded then
      finishFlightAt(state.windowStart + WORKING_TIME)
      playTone(600, 350, 0, PLAY_BACKGROUND)
    end
  end

  handleWorkingAlerts(t)
  handleFlightVoice(t)
end

------------------------------------------------------------
-- UI
------------------------------------------------------------
local function draw()
  lcd.clear()
  lcd.drawText(2, 0, "F3L Training", MIDSIZE)

  local t = nowSeconds()

  if state.showBackHintUntil > t then
    lcd.drawText(2, 18, "Press BACK again", 0)
    lcd.drawText(2, 30, "to reset", 0)
    return
  end

  local work = WORKING_TIME
  if state.windowRunning then
    work = WORKING_TIME - (t - state.windowStart)
  elseif state.windowStart > 0 then
    work = 0
  end
  if work < 0 then work = 0 end

  lcd.drawText(2, 16, "Working:", 0)
  lcd.drawText(70, 16, formatTimePrec(work), 0)

  local flightRem = getFlightRemaining(t)
  lcd.drawText(2, 28, "Flight :", 0)
  lcd.drawText(70, 28, formatTimePrec(flightRem), 0)

  if state.lastFlightDurationFloat ~= nil then
    lcd.drawText(2, 40, "Flight time:", 0)
    lcd.drawText(70, 40, formatTimePrec(state.lastFlightDurationFloat), 0)
  end

  lcd.drawText(2, 55, "ENTER start | SA land | SF WT", SMLSIZE)
end

------------------------------------------------------------
-- init / run
------------------------------------------------------------
local function init()
  local sf = getValue(SF_SOURCE)
  state.sfPrev = (sf ~= nil and sf < 0)

  local sa = getValue(SA_SOURCE)
  if sa ~= nil then state.saPrev = sa end

  state.suppressWorkBeepsUntil = 0
  state.backArmedUntil = 0
  state.enterArmedUntil = 0
end

local function run(event)
  handleInputs(event)
  updateState()
  draw()
end

return { run = run, init = init }
