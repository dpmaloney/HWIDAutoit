
#include <Misc.au3> ; Only used for _Iif
#include <Array.au3>
#include <Date.au3>
Global $LicenseDatabasePath = @ScriptDir & "\licensedatabase.ini"
; // OPTIONS HERE //
Local $sRootDir = @ScriptDir & "\www" ; The absolute path to the root directory of the server.
Local $sIP = "104.154.74.42" ; ip address as defined by AutoIt
Local $iPort = 80 ; the listening port
Local $sServerAddress = "http://" & $sIP & ":" & $iPort & "/"
Local $iMaxUsers = 50 ; Maximum number of users who can simultaneously get/post
Local $sServerName = "ManadarX/1.1 (" & @OSVersion & ") AutoIt " & @AutoItVersion
Local $LicenseKey,$HWID,$EncryptionKey

; // END OF OPTIONS //

Local $aSocket[$iMaxUsers] ; Creates an array to store all the possible users
Local $sBuffer[$iMaxUsers] ; All these users have buffers when sending/receiving, so we need a place to store those

For $x = 0 to UBound($aSocket)-1 ; Fills the entire socket array with -1 integers, so that the server knows they are empty.
    $aSocket[$x] = -1
Next

TCPStartup() ; AutoIt needs to initialize the TCP functions

$iMainSocket = TCPListen($sIP,$iPort) ;create main listening socket
If @error Then ; if you fail creating a socket, exit the application
    MsgBox(0x20, "AutoIt Webserver", "Unable to create a socket on port " & $iPort & ".") ; notifies the user that the HTTP server will not run
    Exit ; if your server is part of a GUI that has nothing to do with the server, you'll need to remove the Exit keyword and notify the user that the HTTP server will not work.
EndIf


ConsoleWrite( "Server created on " & $sServerAddress & @CRLF) ; If you're in SciTE,

While 1
    $iNewSocket = TCPAccept($iMainSocket) ; Tries to accept incoming connections

    If $iNewSocket >= 0 Then ; Verifies that there actually is an incoming connection
        For $x = 0 to UBound($aSocket)-1 ; Attempts to store the incoming connection
            If $aSocket[$x] = -1 Then
                $aSocket[$x] = $iNewSocket ;store the new socket
                ExitLoop
            EndIf
        Next
    EndIf

    For $x = 0 to UBound($aSocket)-1 ; A big loop to receive data from everyone connected
        If $aSocket[$x] = -1 Then ContinueLoop ; if the socket is empty, it will continue to the next iteration, doing nothing
        $sNewData = TCPRecv($aSocket[$x],1024) ; Receives a whole lot of data if possible
        If @error Then ; Client has disconnected
            $aSocket[$x] = -1 ; Socket is freed so that a new user may join
            ContinueLoop ; Go to the next iteration of the loop, not really needed but looks oh so good
		 ElseIf $sNewData Then ; data received



;return code
; return 0 wrong request
; return 1 ok license key and HWID
; return 2 wrong HWID
; return 3 expired license
; return 4 license key not found
Local $returncode = ReadLicenseAndHWIDFromPOST($sNewdata,$LicenseKey,$HWID,$EncryptionKey)
if ($returncode == 0) Then

			;MsgBox(0,"","sent")
			Sleep(100)
   $sBuffer[$x] = "" ; clears the buffer because we just used to buffer and did some actions based on them
                $aSocket[$x] = -1 ; the socket is automatically closed so we reset the socket so that we may accept new clients


Else
$returncode = ValidateLicenseAndHWID($LicenseKey,$HWID)

If ($returncode > 0) Then ; ok vslidated license and hwid
			$encryptedresponse = EncryptReturnCode($EncryptionKey,$returncode)

			_HTTP_SendData($aSocket[$x], $encryptedresponse & 'A', "text/html")
			;MsgBox(0,"","sent")
			Sleep(100)
                $sBuffer[$x] = "" ; clears the buffer because we just used to buffer and did some actions based on them
                $aSocket[$x] = -1 ; the socket is automatically closed so we reset the socket so that we may accept new clients
EndIf

EndIf
        EndIf
    Next

    Sleep(10)
WEnd


Func EncryptReturnCode($Encryptionkey,$returncode)
   $Int = Int($Encryptionkey)
   ; lets do some fun math
   $Int = $Int / 5
   $ret = ($Int * $returncode) + 4522345

   $ret = String($ret)
  return $ret
EndFunc

Func ValidateLicenseAndHWID($License,$HWID); CHECK HWID and WRITES IT INCASE ISNT SAVED
IniReadSection($LicenseDatabasePath,$License)
$errorcode = _WinAPI_GetLastError()
If NOT ($errorcode == 0) Then ; errore probabilmente key section non trovata
   return 4 ; key doesn't exists
EndIf


$HWIDfromdatabase = SetRead("HWID",$License)

   If ($HWIDfromdatabase == -1 Or $HWIDfromdatabase == "") Then; HWID isn't set so let's write it now
	  SetWrite("HWID",$HWID,$License)
   ElseIf ($HWIDfromdatabase == "OFF") Then

   ElseIf NOT ($HWIDfromdatabase == $HWID) Then
	  return 2 ; HWID NOT MATCH
   EndIf
   ; HWID is ok now let's check expiration
   $ExpirationDate = SetRead("Exp",$License)
   $tcur = _Date_Time_EncodeSystemTime(@YEAR,@MON,@MDAY,@HOUR,@MIN,@SEC)
$CurrentTime = _Date_Time_SystemTimeToDateTimeStr($tcur)

If ($ExpirationDate == -1 Or $ExpirationDate == "") Then ;; Expiration date isn't set
   $Days = SetRead("Days",$License)
   $sNewDate = _DateAdd('d', $Days, _NowCalc())
SetWrite("Exp",$sNewDate,$License)
Else
$TimeDifference = _DateDiff ( 's', $CurrentTime, $ExpirationDate )

     If ($TimeDifference > 0) Then
     return 1 ; VALID license key and HWID match
     Else
	 return 3 ; license key expired
     EndIf
EndIf

return 1 ; if the key has just been used for the first time accept it because we created everything
EndFunc

Func ReadLicenseAndHWIDFromPOST($string, ByRef $LicenseKey, ByRef $HWID, ByRef $EncryptionKey)
; XXXX-XXXX-XXXX-XXXX 19 lunghezza caratteri + Yekesnecil: = 11 quindi 30
$LicenseKeyString = "Yekesnecil:"
$HWIDString = "HWID:"
$DefaultLicense = "XXXX-XXXX-XXXX-XXXX" ; per ottenere la lunghezza
$EncryptionKeyString = "ehok:"
; AGGIUNTE PER COMPATIBILITA E FACILITA DI CAMBIO
$LicenseKeyStringLen = StringLen($LicenseKeyString)
$HWIDStringLen = StringLen($HWIDString)
$DefaultLicenseLen = StringLen($DefaultLicense)
$EncryptionKeyStringLen = StringLen($EncryptionKeyString)

$rightedstring = StringRight($string,$LicenseKeyStringLen + $DefaultLicenseLen ) ; 30 lunghezza licenskey + la licenza
$position = StringInStr($rightedstring,$LicenseKeyString)
If NOT ($position == 1) Then ; license key not in the correct position (many causes)
return 0
EndIf
; lets retrieve the license key
$LicenseKey = StringRight($rightedstring,$DefaultLicenseLen) ; lunghezza license key XXXX-.. ecc

; HWID finder
$position = StringInStr($string,$HWIDString)
If ($position == 0) Then return 251 ; return tentativo di crack o altre minchiate

$PostLenght = StringLen($string)
$rightedstring = StringRight($string,$PostLenght - $position - $HWIDStringLen + 1) ; ricavo la stringa del HWID + license il +1 alla fine è per la prima lettera che viene skippata nella position
$HWID = StringTrimRight($rightedstring,$LicenseKeyStringLen + $DefaultLicenseLen)
$HWIDLen = StringLen($HWID) ; needed to find encryption key
; encryptionkey finder
$position = StringInStr($string,$EncryptionKeyString)
If ($position == 0) Then return 251 ; return tentativo di crack o altre minchiate

$PostLenght = StringLen($string)
$rightedstring = StringRight($string,$PostLenght - $position - $EncryptionKeyStringLen + 1) ;
$EncryptionKey = StringTrimRight($rightedstring,$LicenseKeyStringLen + $DefaultLicenseLen + $HWIDStringLen + $HWIDLen )



return 1;
EndFunc



Func SetWrite($variable,$value,$ID)
   IniWrite($LicenseDatabasePath,$ID,$variable,$value)
return
EndFunc

Func SetRead($variable,$ID)
return IniRead($LicenseDatabasePath,$ID,$variable,-1)
EndFunc

Func _HTTP_ConvertString(ByRef $sInput) ; converts any characters like %20 into space 8)
    $sInput = StringReplace($sInput, '+', ' ')
    StringReplace($sInput, '%', '')
    For $t = 0 To @extended
        $Find_Char = StringLeft( StringTrimLeft($sInput, StringInStr($sInput, '%')) ,2)
        $sInput = StringReplace($sInput, '%' & $Find_Char, Chr(Dec($Find_Char)))
    Next
EndFunc

Func _HTTP_SendHTML($hSocket, $sHTML, $sReply = "200 OK") ; sends HTML data on X socket
    _HTTP_SendData($hSocket, Binary($sHTML), "text/html", $sReply)
EndFunc

Func _HTTP_SendFile($hSocket, $sFileLoc, $sMimeType, $sReply = "200 OK") ; Sends a file back to the client on X socket, with X mime-type
    Local $hFile, $sImgBuffer, $sPacket, $a

	ConsoleWrite("Sending " & $sFileLoc & @CRLF)

    $hFile = FileOpen($sFileLoc,16)
    $bFileData = FileRead($hFile)
    FileClose($hFile)

    _HTTP_SendData($hSocket, $bFileData, $sMimeType, $sReply)
EndFunc

Func _HTTP_SendData($hSocket, $bData, $sMimeType, $sReply = "200 OK")
	$sPacket = Binary("HTTP/1.1 " & $sReply & @CRLF & _
    "Server: " & $sServerName & @CRLF & _
	"Connection: close" & @CRLF & _
	"Content-Lenght: " & BinaryLen($bData) & @CRLF & _
    "Content-Type: " & $sMimeType & @CRLF & _
    @CRLF)
    TCPSend($hSocket,$sPacket) ; Send start of packet

    While BinaryLen($bData) ; Send data in chunks (most code by Larry)
        $a = TCPSend($hSocket, $bData) ; TCPSend returns the number of bytes sent
        $bData = BinaryMid($bData, $a+1, BinaryLen($bData)-$a)
    WEnd

    $sPacket = Binary(@CRLF & @CRLF) ; Finish the packet
    TCPSend($hSocket,$sPacket)

	TCPCloseSocket($hSocket)
EndFunc

Func _HTTP_SendFileNotFoundError($hSocket) ; Sends back a basic 404 error
	Local $s404Loc = $sRootDir & "\404.html"
	If (FileExists($s404Loc)) Then
		_HTTP_SendFile($hSocket, $s404Loc, "text/html")
	Else
		_HTTP_SendHTML($hSocket, "404 Error: " & @CRLF & @CRLF & "The file you requested could not be found.")
	EndIf
EndFunc

Func _HTTP_GetPost($s_Buffer) ; parses incoming POST data
    Local $sTempPost, $sLen, $sPostData, $sTemp

    ; Get the lenght of the data in the POST
    $sTempPost = StringTrimLeft($s_Buffer,StringInStr($s_Buffer,"Content-Length:"))
    $sLen = StringTrimLeft($sTempPost,StringInStr($sTempPost,": "))

    ; Create the base struck
    $sPostData = StringSplit(StringRight($s_Buffer,$sLen),"&")

    Local $sReturn[$sPostData[0]+1][2]

    For $t = 1 To $sPostData[0]
        $sTemp = StringSplit($sPostData[$t],"=")
        If $sTemp[0] >= 2 Then
            $sReturn[$t][0] = $sTemp[1]
            $sReturn[$t][1] = $sTemp[2]
        EndIf
    Next

    Return $sReturn
EndFunc

Func _HTTP_Post($sName,$sArray) ; Returns a POST variable like a associative array.
    For $i = 1 to UBound($sArray)-1
        If $sArray[$i][0] = $sName Then
            Return $sArray[$i][1]
        EndIf
    Next
    Return ""
EndFunc