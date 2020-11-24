'no local storage
Sub Main(args)
  url$ = "https://player.fugo.ai"

  reg = CreateObject("roRegistrySection", "networking")
  reg.write("ssh","22")

  n = CreateObject("roNetworkConfiguration", 0)
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
  EnterEventLoop()
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
  sysTime.SetTimeZone("GMT+4")

  DebugLog("BS: Configuring networking...")
  if gaa.config <> invalid then
    ConfigureNetworkingWithConfig()
  else
    ConfigureDefaultNetworking()
  endif

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

Sub CreateHtmlWidget(url$ as String)
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
  gaa.htmlWidget = CreateObject("roHtmlWidget", rect)	'new added config object after rect 5-16-17
  
  DebugLog("BS: Setting URL (" + url$ + " ) ...")
  gaa.htmlWidget.SetUrl(url$)

  DebugLog("BS: Enabling JavaScipt...")
  gaa.htmlWidget.EnableJavascript(true)

  DebugLog("BS: Starting Inspector server...")
  gaa.htmlWidget.StartInspectorServer(2999)

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
    DebugLog("BS: already have an IP addr: "+currentConfig.ip4_address)
  end if

  receivedLoadFinished = false

  while true
    ev = wait(0, gaa.mp)

    DebugLog("BS: Received event: " + type(ev))

    if type(ev) = "roNetworkAttached" then
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
          DebugLog("BS: Message receved: " + eventData.message)
        endif
      else
        DebugLog("BS: Unknown eventData: " + type(eventData))
      endif
    else if type(ev) = "roGpioButton" then
      if ev.GetInt() = 12 then stop
    else if type(ev) = "roTimerEvent" then
      DebugLog("BS: Timer Event at " + Uptime(0))
      DebugLog("BS: User Data:" + ev.GetUserData())
    else
      DebugLog("BS: Unhandled event: " + type(ev))
    end if

    if receivedIpAddr and receivedLoadFinished then
      DebugLog("BS: OK to show HTML, showing widget now")
      gaa.htmlWidget.Show()
      gaa.htmlWidget.PostJSMessage({msgtype:"htmlloaded"})
      receivedIpAddr = false
      receivedLoadFinished = false
    endif
  endwhile
End Sub
