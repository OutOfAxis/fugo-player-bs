Sub Main(args)
  version = "1.11"

  reg = CreateObject("roRegistrySection", "networking")
  reg.write("ssh","22")

  n = CreateObject("roNetworkConfiguration", 0)
  n.SetLoginPassword("password")
  n.Apply()

  reg.flush()

  rs = CreateObject("roRegistrySection", "html")
  mp = rs.Read("mp")
  security = rs.Read("disable-web-security")
  if mp <> "1" or security <> "1" then
      rs.Write("mp","1")
      rs.Write("disable-web-security","1")
      rs.Flush()
      RebootSystem()
  endif

  webInspector = rs.Read("enable_web_inspector")
  if webInspector <> "1" then
      rs.Write("enable_web_inspector", "1")
      rs.Flush()
  endif

  gaa = GetGlobalAA()
  gaa.version = version

  ' display cursor and hide it in a corner
  gaa.touchScreen = CreateObject("roTouchScreen")
  if gaa.touchScreen.IsMousePresent() then
      gaa.touchScreen.EnableCursor(true)
      gaa.touchScreen.SetCursorPosition(0, 0)
  endif

  DoCanonicalInit()
  CreateHtmlWidget()
  EnterEventLoop()
End Sub

Sub OpenOrCreateCurrentLog()
  fileName$ = "log.txt"
  m.logFile = CreateObject("roAppendFile", fileName$)
  if type(m.logFile) = "roAppendFile" then
      return
  endif
  m.logFile = CreateObject("roCreateFile", fileName$)
End Sub

Sub LoadConfig()
  gaa = GetGlobalAA()

  gaa.config = ParseJson(ReadAsciiFile("/bs-player-config.json"))
  if gaa.config <> invalid then
    DebugLog("BS: Configuration loaded")
  else
    DebugLog("BS: Could not load configuration")
  endif
End Sub

Sub DebugLog(message as String)
  print message
  gaa = GetGlobalAA()

  gaa.syslog.SendLine(message)
  if gaa.syslog <> invalid then
    gaa.syslog.SendLine(message)
  endif

  if m <> invalid then
    m.logFile.SendLine(message)
    m.logFile.AsyncFlush()
  endif
End Sub

Sub DoCanonicalInit()
  gaa =  GetGlobalAA()
  gaa.syslog = CreateObject("roSystemLog")

  OpenOrCreateCurrentLog()

  DebugLog("BS: Fugo App Shell v." + gaa.version)
  DebugLog("BS: Start Initialization")

  DebugLog("BS: Enabling Zone Support...")
  EnableZoneSupport(1)

  DebugLog("BS: Creating message port...")
  gaa.mp = CreateObject("roMessagePort")

  DebugLog("BS: Setting GPIO control port...")
  gaa.gpioPort = CreateObject("roGpioControlPort")
  gaa.gpioPort.SetPort(gaa.mp)

  DebugLog("BS: Setting video mode...")
  gaa.vm = CreateObject("roVideoMode")
  gaa.vm.setMode("1920x1080x60p")

  DebugLog("BS: Setting network hotplug...")
  gaa.hp = CreateObject("roNetworkHotplug")
  gaa.hp.setPort(gaa.mp)

  DebugLog("BS: Loading configuration...")
  LoadConfig()

  DebugLog("BS: Setting system time...")
  sysTime = CreateObject("roSystemTime")
  sysTime.SetTimeZone("PST")

  DebugLog("BS: Configuring networking...")
  if gaa.config <> invalid then
    ConfigureNetworkingWithConfig()
  else
    ConfigureDefaultNetworking()
  endif

  ' Start autoupdate timer
  gaa.syslog.SendLine("BS: Starting autoupdate timer")
  gaa.autoupdateTimer = CreateObject("roTimer")
  gaa.autoupdateTimer.SetPort(gaa.mp)
  gaa.autoupdateTimer.SetElapsed(600, 0)
  gaa.autoupdateTimer.SetUserData("checkUpdate")
  gaa.autoupdateTimer.Start()

  DebugLog("BS: Initialization completed")
End Sub

Sub ConfigureDefaultNetworking()
  DebugLog("BS: Configuring Ethernet network")

  nc = CreateObject("roNetworkConfiguration", 0)
  if type(nc) = "roNetworkConfiguration" then
    DebugLog("BS: Setting up DWS...")
    dwsAA = CreateObject("roAssociativeArray")
    dwsAA["port"] = "80"
    nc.SetupDWS(dwsAA)

    DebugLog("BS: Enabling DHCP...")
    nc.SetDHCP()

    DebugLog("BS: Setting timeserver address...")
    nc.SetTimeServer("http://time.brightsignnetwork.com")

    DebugLog("BS: Adding DNS servers...")
    nc.AddDNSServer("8.8.8.8")

    success = nc.Apply()
    if not success then
      DebugLog("BS: Applying default network configuration failure")
    endif
  else
    DebugLog("BS: Network interface default initialization failure")
  endif
End Sub

Sub ConfigureNetworkingWithConfig()
  if gaa.config.wifi then
    DebugLog("BS: Configuring WiFi network")
    nc = CreateObject("roNetworkConfiguration", 1)
  else
    DebugLog("BS: Configuring Ethernet network")
    nc = CreateObject("roNetworkConfiguration", 0)
  endif

  if type(nc) = "roNetworkConfiguration" then
    DebugLog("BS: Setting up DWS...")
    dwsAA = CreateObject("roAssociativeArray")
    dwsAA["port"] = "80"
    nc.SetupDWS(dwsAA)

    if gaa.config.wifi then
      DebugLog("BS: Enabling WiFi...")
      nc.SetWiFiESSID(gaa.config.ssid)
      nc.SetWiFiPassphrase(gaa.config.passphrase)
    endif

    if gaa.config.dhcp then
      DebugLog("BS: Enabling DHCP...")
      nc.SetDHCP()
    else
      DebugLog("BS: Setting static network configuration...")
      nc.SetIP4Address(gaa.config.ip)
      nc.SetIP4Netmask(gaa.config.netmask)
      nc.SetIP4Gateway(gaa.config.gateway)
    endif

    if gaa.config.timeServer <> "" then
      DebugLog("BS: Setting timeserver address...")
      nc.SetTimeServer(gaa.config.timeServer)
    endif

    if gaa.config.dns1 <> "" or gaa.config.dns2 <> "" or gaa.config.dns3 <> "" then
      DebugLog("BS: Adding DNS servers...")
    endif
    if gaa.config.dns1 <> "" then nc.AddDNSServer(gaa.config.dns1)
    if gaa.config.dns2 <> "" then nc.AddDNSServer(gaa.config.dns2)
    if gaa.config.dns3 <> "" then nc.AddDNSServer(gaa.config.dns3)

    success = nc.Apply()
    if not success then
      DebugLog("BS: Applying network configuration failure")
    endif
  else
    DebugLog("BS: Network interface initialization failure")
  endif
End Sub

Sub CreateHtmlWidget()
  DebugLog("BS: Creating HTML Widget")

  gaa = GetGlobalAA()
  width = gaa.vm.GetResX()
  height = gaa.vm.GetResY()

  if gaa.htmlWidget <> invalid then
    DebugLog("BS: Hidding html widget...")
    gaa.htmlWidget.Hide()
  endif

  DebugLog("BS: Creating rectangle...")
  rect = CreateObject("roRectangle", 0, 0, width, height)

  DebugLog("BS: Creating Html widget...")
  config = {
    url: "https://player.fugo.ai",
    focus_enabled: true,
    mouse_enabled: true,
    javascript_enabled: true,
    brightsign_js_objects_enabled: true,
    nodejs_enabled: true,
    storage_path: "./fugo-storage",
    storage_quota: 1073741824,
    security_params: {
      websecurity: false,
    }
  }

  gaa.htmlWidget = CreateObject("roHtmlWidget", rect, config)
  gaa.htmlWidget.SetPort(gaa.mp)

  if gaa.touchScreen.IsMousePresent() then
    gaa.htmlWidget.EnableScrollbars(true)
    if MatchFiles("/", "bsvirtualkb").Count() > 0 then
      DebugLog("BS: Creating virtual keyboard...")
      gaa.virtualKeyboard = CreateObject("roVirtualKeyboard", rect)
      gaa.virtualKeyboard.SetResource("file:///bsvirtualkb/bsvirtualkb.html")
      gaa.virtualKeyboard.SetPort(gaa.mp)
    end if
  end if

  DebugLog("BS: Displaying Html widget...")
  gaa.htmlWidget.Show()
End Sub

Sub EnterEventLoop()
  DebugLog("BS: Running handle events loop")

  gaa =  GetGlobalAA()
  nc = CreateObject("roNetworkConfiguration", 0)
  currentConfig = nc.GetCurrentConfig()

  receivedIpAddr = false

  if currentConfig.ip4_address <> "" then
    ' We already have an IP addr
    receivedIpAddr = true
    DebugLog("BS: Already have an IP addr: " + currentConfig.ip4_address)
  end if

  receivedLoadFinished = false
  receivedLoadError = false

  while true
    ev = wait(0, gaa.mp)

    DebugLog("BS: Received event: " + type(ev))

    if type(ev) = "roNetworkAttached" then
      receivedIpAddr = true
      if gaa.htmlWidget <> invalid and receivedLoadError then
        Sleep(10000)
        DebugLog("BS: Trying to recreate HTML widget")
        CreateHtmlWidget()
        receivedLoadError = false
      endif
    else if type(ev) = "roHtmlWidgetEvent" then
      eventData = ev.GetData()
      if type(eventData) = "roAssociativeArray" and type(eventData.reason) = "roString" then
        DebugLog("BS: Event data: " + FormatJson(ev.GetData(), 0))
        if eventData.reason = "load-error" then
          DebugLog("BS: HTML load error: " + eventData.message)
          receivedLoadError = true
        else if eventData.reason = "load-finished" then
          DebugLog("BS: Received load finished")
          receivedLoadFinished = true
        else if eventData.reason = "message" then
          DebugLog("BS: Message receved: " + FormatJson(eventData.message, 0))
        endif
      else
        DebugLog("BS: Unknown eventData: " + type(eventData))
      endif
    else if type(ev) = "roTimerEvent" then
      timerData = ev.GetUserData()
      if timerData = "checkUpdate" then
        DebugLog("BS: Checking for update")
        versionRequest = CreateObject("roUrlTransfer")
        versionRequestPort = CreateObject("roMessagePort")
        versionRequest.SetUrl("https://raw.githubusercontent.com/OutOfAxis/fugo-player-bs/main/latest.txt")
        versionRequest.SetPort(versionRequestPort)
        if versionRequest.AsyncGetToString() then
          event = wait(5000, versionRequestPort)
          if type(event) = "roUrlEvent" then
            if event.GetResponseCode() = 200 then
              latestVersion = event.GetString().Trim()
              DebugLog("BS: Latest version: " + latestVersion)
              if gaa.version = latestVersion then
                DebugLog("BS: Already up to date")
              else
                DebugLog("BS: Retrieving latest autorun.brs")
                scriptRequest = CreateObject("roUrlTransfer")
                scriptRequest.SetUrl("https://raw.githubusercontent.com/OutOfAxis/fugo-player-bs/main/autorun.brs")
                responseCode = scriptRequest.GetToFile("autorun.tmp")
                DebugLog("BS: Response code = " + stri(responseCode))
                if responseCode = 200 then
                  DebugLog("BS: Performing update")
                  MoveFile("autorun.brs", "autorun.brs~")
                  MoveFile("autorun.tmp", "autorun.brs")
                  RebootSystem()
                end if
              end if
            else
              DebugLog("BS: Request error: " + event.GetFailureReason())
            end if
          else if event = invalid then
            DebugLog("BS: Request timeout")
            versionRequest.AsyncCancel()
          end if
        else
          DebugLog("BS: Request could not be issued")
        end if
        gaa.autoupdateTimer.Start()
      end if
    else if type(ev) = "roVirtualKeyboardEvent" then
      if ev.GetData().reason = "show-event"
        gaa.virtualKeyboard.Show()
      endif
      if ev.GetData().reason = "hide-event"
        gaa.virtualKeyboard.Hide()
      endif
    else
      DebugLog("BS: Unhandled event: " + type(ev))
    end if

    if receivedIpAddr and receivedLoadFinished then
      DebugLog("BS: OK to show HTML, showing widget now")
      gaa.htmlWidget.Show()
      gaa.htmlWidget.PostJSMessage({ msgtype: "htmlloaded" })
      receivedIpAddr = false
      receivedLoadFinished = false
    endif
  endwhile
End Sub