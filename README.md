# NetworkReading
Powershell module for capturing GET requests of network traffic (using ngrep)

Can be used for live capturing of all video streams (for example m3u8 playlists) viewed in any browser

##Prerequisites
- ngrep
- ffmpeg (for streams capturing)

##OS
- Windows (PS 5)
- Linux (PS 6 alpha)

##Cmdlets
- Start-NetworkReading
- Stop-NetworkReading
- Test-NetworkReading
- Get-NetworkReadingOutputUrl
- Select-NetworkReadingOutputUrl
- Save-NetworkStream
- Receive-NetworkStreamData


Howto list all GET data downloaded by your browser?

1. Install NetworkReading module
2. Start network traffic listening with Start-NetworkReading 
3. Open your preferred browser and watch any page
4. Run Get-NetworkReadingOutputUrl 


Howto capture all video streams (m3u8 playlists) viewed in your browser?

Linux:

    Start-NetworkReading | Receive-NetworkStreamData -OutputDirectory "/temp"

Windows: 

Choose your network device number by "ngrep -L", ffmpeg and ngrep must be in your PATH

    Start-NetworkReading -DeviceNumber 6 | Receive-NetworkStreamData -OutputDirectory "c:\temp"

    
    
    
    
