'name file autorun.zip
' Content update application
path$="SD:/"	'USB1, SSD2, SD2
r=CreateObject("roRectangle", 20, 668, 1240, 80)
t=CreateObject("roTextWidget",r,1,2,1)
r=CreateObject("roRectangle", 20, 20, 1200, 40)
t.SetSafeTextRegion(r)

t.SetForegroundColor(&hff303030)
t.SetBackgroundColor(&hffffffff)
t.PushString("Updating content from USB drive, please wait...")
package = CreateObject("roBrightPackage", path$+"autorun.zip")
'package.SetPassword("test")
package.Unpack("SD:/")
package = 0
t.PushString("Update complete - Preparing to restart.")

CreateDirectory(path$+"feed_cache")
CreateDirectory(path$+"feedPool")
CreateDirectory(path$+"brightsign-dumps")

DeleteFile(path$+"autozip.brs")
DeleteFile(path$+"autorun.zip")
a=RebootSystem()