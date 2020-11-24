'no local storage
Sub Main(args)
  url$ = "https://player.fugo.ai"
  ' url$ = "https://google.com"
  ' url$ = "file:///index.html"

  ' 'url$ = "http://www.mysitehere.com" disabled
  ' if args <> invalid and args.Count() > 0 then
  '   url$ = args[0]
  ' end if
  ' print "url = ";url$

  reg = CreateObject("roRegistrySection", "networking")
  reg.write("ssh","22")

  n=CreateObject("roNetworkConfiguration", 0)
  n.SetLoginPassword("password")
  n.Apply()

  reg.flush()

  'reboots if html node not already enabled
  rs = createobject("roregistrysection", "html")
  mp = rs.read("mp")
  if mp <> "1" then
      rs.write("mp","1")
      rs.flush()
      RebootSystem()
  endif

  DoCanonicalInit()
  CreateHtmlWidget(url$)
  ' DefaultHtmlWidget()
  HandleEvents()
End Sub

' Sub ReloadConfig()
'   gaa = GetGlobalAA()
'   gaa.config = ParseJson(ReadAsciiFile("/bs-player-config.json"))
'   if type(gaa.syslog) = "roSystemLog" then
'     gaa.syslog.SendLine("BS: BSPlayer configuration loaded")
'   endif
' End Sub

' Sub DefaultHtmlWidget()
'   contentUrl$ = "file:///content/index.html"
'   CreateHtmlWidget(contentUrl$)
' End Sub

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

  DebugLog("BS: Start Initialization")

  DebugLog("BS: Enabling Zone Support...")
  EnableZoneSupport(1)

  ' Enable mouse cursor
  ' gaa.touchScreen = CreateObject("roTouchScreen")
  ' gaa.touchScreen.EnableCursor(true)

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

  ' Load BS Player configuration
  ' ReloadConfig()

  DebugLog("BS: Setting system time...")
  sysTime = CreateObject("roSystemTime")
  sysTime.SetTimeZone("GMT+4")

  DebugLog("BS: Configuring networking...")
  if gaa.config <> invalid then
    ConfigureNetworkingWithConfig()
  else
    ConfigureDefaultNetworking()
  endif

  ' Start timer
  ' gaa.syslog.SendLine("BS: Starting screenshot timer")
  ' gaa.screenshotTimer = CreateObject("roTimer")
  ' gaa.screenshotTimer.SetPort(gaa.mp)
  ' gaa.screenshotTimer.SetElapsed(5, 0)
  ' gaa.screenshotTimer.SetUserData({msgtype:"takeScreenshot"})
  ' gaa.screenshotTimer.Start()

  DebugLog("BS: Initialization completed")
End Sub

Sub ConfigureDefaultNetworking()
  DebugLog("BS: Configuring Ethernet network")
  nc = CreateObject("roNetworkConfiguration", 0)
  if type(nc) = "roNetworkConfiguration" then
    DebugLog("BS: Setup DWS")

    dwsAA = CreateObject("roAssociativeArray")
    dwsAA["port"] = "80"
    nc.SetupDWS(dwsAA)

    DebugLog("BS: Enabling DHCP")
    nc.SetDHCP()

    DebugLog("BS: Setting timeserver address")
    nc.SetTimeServer("http://time.brightsignnetwork.com")

    DebugLog("BS: Adding DNS servers")
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
    DebugLog("BS: Setup DWS")
    dwsAA = CreateObject("roAssociativeArray")
    dwsAA["port"] = "80"
    nc.SetupDWS(dwsAA)

    if gaa.config.wifi then
      nc.SetWiFiESSID(gaa.config.ssid)
      nc.SetWiFiPassphrase(gaa.config.passphrase)
    endif

    if gaa.config.dhcp then
      DebugLog("BS: Enabling DHCP")
      nc.SetDHCP()
    else
      DebugLog("BS: Setting static network configuration")
      nc.SetIP4Address(gaa.config.ip)
      nc.SetIP4Netmask(gaa.config.netmask)
      nc.SetIP4Gateway(gaa.config.gateway)
    endif

    if gaa.config.timeServer <> "" then
      DebugLog("BS: Setting timeserver address")
      nc.SetTimeServer(gaa.config.timeServer)
    endif

    if gaa.config.dns1 <> "" or gaa.config.dns2 <> "" or gaa.config.dns3 <> "" then
      DebugLog("BS: Adding DNS servers")
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

' Function FormatDateTime(dt)
'   ' 2010-06-30T01:20
'   pad = Function(s)
'     st = s.Trim()
'     if st.Len() = 2 then
'       Return st
'     else
'       Return "0" + st
'     end if
'   End Function
'   Return dt.GetYear().ToStr() + "-" + pad(strI(dt.GetMonth())) + "-" + pad(strI(dt.GetDay())) + "T" + pad(strI(dt.GetHour())) + ":" + pad(strI(dt.GetMinute())) + ":" + pad(strI(dt.GetSecond())) + "+04:00"
' End Function

' Sub CreateNodeWidget(url$ as String)
'   ga =  GetGlobalAA()
'   width=ga.vm.GetResX()
'   height=ga.vm.GetResY()
'   rect=CreateObject("roRectangle", 0, 0, width, height)

'   ga.syslog.SendLine("BS: Creating Node Widget")

'   'new node 5-16-17
'   is = {
'       port: 2998
'   }
'   config = {
'     nodejs_enabled: true
'     inspector_server: is
'     brightsign_js_objects_enabled: true
'     focus_enabled: true
'     javascript_enabled: true
'     url: url$
'     storage_path: "SD:"
'     storage_quota: 1073741824
'   }
'   'end new

'   ga.nodeWidget = CreateObject("roHtmlWidget", rect, config)	'new added config object after rect 5-16-17
'   ga.nodeWidget.SetPort(ga.mp)
'   ga.nodeWidget.Show()
' End Sub

Function OrientationToTransform(orientation as String)
  transform = "identity"
  if orientation = "90" then transform = "rot90"
  if orientation = "270" then transform = "rot270"
  Return transform
End Function

Sub CreateHtmlWidget(url$ as String)
  ga = GetGlobalAA()
  width=ga.vm.GetResX()
  height=ga.vm.GetResY()

  DebugLog("BS: Create HTML Widget")

  if ga.htmlWidget <> invalid then
    DebugLog("BS: Hidding html widget...")
    ga.htmlWidget.Hide()
  endif

  DebugLog("BS: Creating rectangle...")
  rect=CreateObject("roRectangle", 0, 0, width, height)

  'new node 5-16-17
  transform = "identity"
  is = {
      port: 2999
  }
  config = {
    ' nodejs_enabled: true
    inspector_server: is
    ' brightsign_js_objects_enabled: true
    ' focus_enabled: true
    javascript_enabled: true
    ' hwz_default: "on"
    url: url$
    transform: transform
    storage_path: "SD:"
    ' storage_quota: 1073741824
  }
  'end new

  DebugLog("BS: Creating Html widget...")
  ga.htmlWidget = CreateObject("roHtmlWidget", rect)	'new added config object after rect 5-16-17
  
  DebugLog("BS: Setting URL (" + url$ + " ) ...")
  ga.htmlWidget.SetUrl(url$)

  DebugLog("BS: Enabling JavaScipt...")
  ga.htmlWidget.EnableJavascript(true)

  DebugLog("BS: Starting Inspector server on port 2999...")
  ga.htmlWidget.StartInspectorServer(2999)

  DebugLog("BS: Displaying Html widget...")
  ga.htmlWidget.Show()

  if type(ga.syslog) = "roSystemLog" then
    DebugLog("BS: HTML widget loaded: " + url$)
  endif
End Sub

Sub HandleEvents()
  gaa =  GetGlobalAA()

  di = CreateObject("roDeviceInfo")
  si = CreateObject("roStorageInfo", "SD:")
  nc = CreateObject("roNetworkConfiguration", 0)

  receivedIpAddr = false
  currentConfig = nc.GetCurrentConfig()
  if currentConfig.ip4_address <> "" then
    ' We already have an IP addr
    receivedIpAddr = true
    gaa.syslog.SendLine("BS: already have an IP addr: "+currentConfig.ip4_address)
  end if

  gaa.syslog.SendLine("BS: Running handle events loop")

  receivedLoadFinished = false
  while true
    ev = wait(0, gaa.mp)
    ' print "BS: Received event ";type(ev)
    ' print "BS: Event data ";ev.GetData()
    gaa.syslog.SendLine("BS: Received event: " + type(ev))
    if type(ev) = "roNetworkAttached" then
      DebugLog("BS: Received roNetworkAttached")
      receivedIpAddr = true
    else if type(ev) = "roHtmlWidgetEvent" then
      eventData = ev.GetData()
      if type(eventData) = "roAssociativeArray" and type(eventData.reason) = "roString" then
        DebugLog("BS: Event data: " + FormatJson(ev.GetData(), 0))
        if eventData.reason = "load-error" then
          DebugLog("BS: HTML load error: " + eventData.message)
        else if eventData.reason = "load-finished" then
          DebugLog("BS: Received load finished")
          receivedLoadFinished = true
        else if eventData.reason = "message" then
          ' To use this: msgPort.PostBSMessage({text: "my message"});
              'm.logFile.SendLine(eventData.message.text)
              'm.logFile.AsyncFlush()
          if eventData.message.msgtype = "loadurl" then
            DebugLog("BS: Loading URL: " + eventData.message.url)
            CreateHtmlWidget(eventData.message.url)
          else if eventData.message.msgtype = "orientationChanged" then
            DebugLog("BS: Updating orientation")
            ' ReloadConfig()
            ' DefaultHtmlWidget()
          else if eventData.message.msgtype = "reboot" then
            DebugLog("BS: Rebooting player")
            RebootSystem()
          endif
        endif
      else
        print "BS: Unknown eventData: "; type(eventData)
      endif
    else if type(ev) = "roGpioButton" then
      if ev.GetInt() = 12 then stop
    else if type(ev) = "roTimerEvent" then
      print "BS: Timer Event at "; Uptime(0)
      print "BS: User Data:"; ev.GetUserData()
      ' ' Saving screenshot
      ' screenshotIsSaved = gaa.vm.Screenshot({
      '   filename: "SD:/screenshot.jpeg"
      '   width: 320
      '   height: 200
      '   filetype: "JPEG"
      '   async: 0
      ' })
      ' if screenshotIsSaved
      '   print "BS: Screenshot has been saved"
      ' else
      '   print "BS: Error saving screenshot"
      ' end if
      ' ' Sending screenshot
      ' print "BS: Sending screenshot for playerId="; gaa.config.id
      ' ut = CreateObject("roUrlTransfer")
      ' ut.SetUrl("http://" + gaa.config.logServerUri + "/log-data/android/screenshot/" + gaa.config.id)
      ' statusCode = ut.PutFromFile("/screenshot.jpeg")
      ' print "BS: Screenshot sent: "; statusCode
      ' ' Sending system log
      ' ut = CreateObject("roUrlTransfer")
      ' ut.SetUrl("http://" + gaa.config.logServerUri + "/log-data/android/system-report")
      ' ut.AddHeader("Content-Type", "application/json")
      ' st = CreateObject("roSystemTime")
      ' lastOnline = CreateObject("roDateTime")
      ' systemStartTime = CreateObject("roDateTime")
      ' loadavg = di.GetLoadStatistics({item:"loadavg"})
      ' meminfo = di.GetLoadStatistics({item:"meminfo"})
      ' netconf = nc.GetCurrentConfig()
      ' timestamp = st.GetLocalDateTime().ToSecondsSinceEpoch()
      ' lastOnline.FromSecondsSinceEpoch(timestamp)
      ' systemStartTime.FromSecondsSinceEpoch(timestamp - di.GetDeviceUptime())
      ' cpuRe = CreateObject("roRegex", "^([0-9.]+)", "")
      ' memRe = CreateObject("roRegex", "MemTotal:\s*(\d+).*MemFree:\s*(\d+).*MemAvailable:\s*(\d+).*", "ms")
      ' memusage = memRe.Match(meminfo)
      ' cpuload = (val(cpuRe.Match(loadavg)[1])*100) MOD 101
      ' logData = CreateObject("roAssociativeArray")
      ' logData["playerId"] = gaa.config.id
      ' logData["modelName"] = di.GetModel()
      ' logData["systemVersion"] = di.GetVersion()
      ' logData["appVersion"] = "0.1"
      ' logData["systemStartTime"] = FormatDateTime(systemStartTime)
      ' logData["totalCapacity"] = si.GetSizeInMegabytes()
      ' logData["totalFreeSpace"] = si.GetFreeInMegabytes()
      ' logData["cpuUsage"] = strI(cpuload).Trim() + "%"
      ' logData["memoryTotal"] = 0
      ' logData["memoryUsed"] = 0
      ' logData["ipAddress"] = netconf.ip4_address
      ' logData["lastOnline"] = FormatDateTime(lastOnline)
      ' payload = FormatJson(logData, 0)
      ' print payload
      ' statusCode = ut.PutFromString(payload)
      ' print "BS: System log sent: "; statusCode
      ' print "BS: Cleaning up memory"
      ' ut = invalid
      ' netconf = invalid
      ' logData = invalid
      ' RunGarbageCollector()
      ' gaa.screenshotTimer.Start()
    else
      DebugLog("BS: Unhandled event: " + type(ev))
    end if
    if receivedIpAddr and receivedLoadFinished then
      DebugLog("BS: OK to show HTML, showing widget now")
      gaa.htmlWidget.Show()
      ' gaa.nodeWidget.Show()
      gaa.htmlWidget.PostJSMessage({msgtype:"htmlloaded"})
      receivedIpAddr = false
      receivedLoadFinished = false
    endif
  endwhile
End Sub

Sub OpenOrCreateCurrentLog()
  ' if there is an existing log file for today, just append to it. otherwise, create a new one to use
  fileName$ = "log.txt"
  m.logFile = CreateObject("roAppendFile", fileName$)
  if type(m.logFile) = "roAppendFile" then
      return
  endif
  m.logFile = CreateObject("roCreateFile", fileName$)
End Sub
