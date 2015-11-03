http = require 'http'
url  = require 'url'
fs   = require 'fs'
mimeTypes = require 'mimetype'
querystring = require 'querystring'
request = require 'request'

guid = require 'guid'
_ = require 'underscore'

class KeyOSLicenseAcquirer
    
    constructor: ->
        @data =
            APIKey: ''
            Challenge: ''
            ContentId: ''
            Systeminfo: ''
            UserIP: ''
            ProfileId: ''
            WMRMProfile: ''
            KeyId: ''
            RMId: '0'
            XRMId: '00000000-0000-0000-0000-000000000000'
        
        @options =
            url: 'http://wmrm.api.licensekeyserver.com'
            method: 'POST'
            headers:
                'SOAPAction': 'http://wmrm.api.licensekeyserver.com/WMRMLicenseService/GenerateLicense'
                'User-Agent': 'Ayyo.ru'
                'Content-Type': 'text/xml;charset=UTF-8'
    
    setChallenge: (data)->
        @data.Challenge = data
    
    setAPIKey: (data)->
        @data.APIKey = data
    
    setSystemInfo: (data)->
        @data.Systeminfo = data
    
    setUserIP: (data)->
        @data.UserIP = data
    
    setProfileID: (data)->
        @data.ProfileId = data
    
    setWMRMProfile: (data)->
        @data.WMRMProfile = data
    
    setContentID: (data)->
        unless data
            return @data.ContentId
        
        @data.ContentId = data
    
    setKeyID: (data)->
        @data.KeyId = data
    
    setRMID: (data)->
        unless data
            return @data.RMId
        
        @data.RMId = data
    
    setXRMID: (data)->
        @data.XRMId = data
    
    setIsNonsilent: (data)->
        @isNonsilent = data
    
    isNonsilent: ->
        return @isNonsilent
    
    getChallenge: ->
        if _.isEmpty @data
            throw new Error 'Please fill in data to send to license service.'
        
        unless @data.APIKey
            throw new Error 'APIKey wasn\'t set'
        
        unless @data.Challenge or @data.Systeminfo
            throw new Error 'Neither challenge nor system info were set.'
        
        unless @data.ContentId
            throw new Error 'ContentID wasn\'t set'
        
        unless @data.UserIP
            throw new Error 'UserIP wasn\'t set'
        
        reqTemplate = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                        <SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ns1=\"http://wmrm.api.licensekeyserver.com\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
                            <SOAP-ENV:Body>
                                <ns1:GenerateLicense>
                                    <ns1:LicenseRequest>
                                        <ns1:APIKey>#{@data.APIKey}</ns1:APIKey>
                                        <ns1:Challenge>#{@data.Challenge}</ns1:Challenge>
                                        <ns1:ContentId>#{@data.ContentId}</ns1:ContentId>
                                        <ns1:UserIP>#{@data.UserIP}</ns1:UserIP>
                                        <ns1:ProfileId>#{@data.ProfileId}</ns1:ProfileId>
                                        <ns1:KeyId>#{@data.KeyId}</ns1:KeyId>
                                        <ns1:RMId>#{@data.RMId}</ns1:RMId>
                                        <ns1:XRMId>#{@data.XRMId}</ns1:XRMId>
                                    </ns1:LicenseRequest>
                                </ns1:GenerateLicense>
                            </SOAP-ENV:Body>
                        </SOAP-ENV:Envelope>"

        return reqTemplate

encoding = (options)->
    str = options.message
    buffer = new Buffer str.length * 2
    buffer.write str, 0, buffer.length, 'utf16le'
    
    coded = buffer.toString('base64')
    coded = coded.replace(/\+/g, '!').replace(/\//g, '*') if options.alphabet
    return coded

decoding = (options)->
    coded = options.message
    if options.alphabet
        coded = coded.replace /!/g, '+'
        coded = coded.replace /\*/g, '/'
    
    buffer = new Buffer coded, 'base64'
    return buffer.toString()

setHeader = (res, contentType)->
    contentType = contentType ? "text/plain"
    res.writeHead 200,
        "Content-Type": contentType
        "Access-Control-Allow-Credentials": false
        "Access-Control-Allow-Headers": "origin, authorization, content-type, accept"
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE"
        "Access-Control-Allow-Origin": "*"
        "Access-Control-Max-Age": 10

getPost = (req)->
    postData = ''
    req.on 'data', (chunk)->
        postData += chunk
    
    req.on 'end', ->
        #postData = querystring.parse postData
        req.emit 'postData', postData

    return req
    
console.log 'Encoding server'

http.createServer (req, res)->
    urlParsed = url.parse(req.url)
    uri = urlParsed.pathname
    
    switch uri
        when '/e/'
            getPost(req).on 'postData', (postData)->
                postData = querystring.parse postData
                coded = encoding postData
                setHeader res
                res.end coded
        
        when '/d/'
            getPost(req).on 'postData', (postData)->
                postData = querystring.parse postData
                str = decoding postData
                setHeader res
                res.end str
        
        when '/save/'
            getPost(req).on 'postData', (postData)->
                query = querystring.parse urlParsed.query
                filename = query.filename
                
                fs.writeFile filename, postData, (err)->
                    throw err if err
                    console.log "#{filename} saved"

                setHeader res
                res.end 'OK'
        
        when '/cad/'
            query = querystring.parse urlParsed.query
            
            drmSystemID = 'urn:dvb:casystemid:19170'
            mediaFormat = 'ASF_DCF'
            videoCoding = 'WMV_SD_30'
            audioCoding = 'WMA'
        
            mimeType = 'application/vnd.oma.drm.dcf'
            
            cad = """
                  <Contents>
                     <ContentItem>
                         <Title>Title</Title>
                         <Synopsis>Synopsis</Synopsis>
                         <OriginSite>http://ayyo.ru</OriginSite>
                         <OriginSiteName>Ayyo Ru</OriginSiteName>
                         <ContentID>#{query.cid}</ContentID>
                         <ContentURL DRMSystemID="#{drmSystemID}" TransferType="streaming" Size="-1" MIMEType="#{mimeType}" MediaFormat="#{mediaFormat}" VideoCoding="#{videoCoding}" AudioCoding="#{audioCoding}">#{query.url}</ContentURL>
                         <DRMControlInformation>
                             <DRMSystemID>#{drmSystemID}</DRMSystemID>
                             <DRMContentID>#{query.cid}</DRMContentID>
                             <RightsIssuerURL>http://10.33.26.14/send/</RightsIssuerURL>
                             <SilentRightsURL>http://10.33.26.14/send/</SilentRightsURL>
                         </DRMControlInformation>
                     </ContentItem>
                  </Contents>
                  """
                
            console.log cad

            setHeader res, 'text/xml;charset=UTF-8'
            res.end cad

        when '/challenge/'
            getPost(req).on 'postData', (postData)->
                postData = querystring.parse postData

                acquirer = new KeyOSLicenseAcquirer
                
                challenge = postData.challenge ? "<LICENSEREQUEST version=\"2.0.0.0\"><ACTIONLIST><ACTION>Play</ACTION></ACTIONLIST>#{postData.message}<WRMHEADER version=\"2.0.0.0\"></WRMHEADER></LICENSEREQUEST>"
                unless postData.challenge
                    challenge = encoding message: challenge, alphabet: true

                acquirer.setAPIKey 'c2ce9bf9-887e-6021-389b-630ca50282fa'
                acquirer.setChallenge challenge
                acquirer.setContentID guid.encode postData.cid
                acquirer.setKeyID guid.encode postData.cid
                acquirer.setUserIP '10.11.12.13'
                acquirer.setProfileID '1612'

                challenge = acquirer.getChallenge()
                setHeader res
                res.end querystring.stringify challenge: challenge

        when '/favicon.ico'
            res.end()

        else
            setHeader res, mimeTypes.lookup(uri)
            fs.readFile __dirname + '/' + uri, (err, contents)->
                throw err if err
                res.end contents

.listen process.env.PORT, process.env.IP
