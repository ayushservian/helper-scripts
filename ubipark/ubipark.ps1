function GetReqVerToken ([String]$WebResp) {
    return GetFormData $WebResp "__RequestVerificationToken"
}

function GetFormData  {
    [CmdletBinding()]
    param([String]$WebResp, [String]$Data)
    $DataValue = "404"
    if($WebResp.Contains($Data)) {
        $Index1 = $WebResp.IndexOf("$Data")
        $ReqVerStart = $WebResp.Substring($Index1)
        $IndexVal = $ReqVerStart.IndexOf("value=")
        $IndexEnd = $ReqVerStart.IndexOf("/>")
        $DataValue = $ReqVerStart.Substring($IndexVal + 6, $IndexEnd - $IndexVal - 7).Replace("`"","")
    }
    # Write-Verbose $Data $DataValue
    return $DataValue
}

function GetUbiParkVals {
    Write-Host "Getting values from ubiparkCreds.json of format {email: '', pass: '', baseUri: '', carParkID: ''}"
    $creds = Get-Content -Raw -Path .\ubiparkCreds.json | ConvertFrom-Json

    if($null -eq $creds){
        Write-Host "No creds json found!!"
        return $null;
    }

    return $creds
}
function GetUbiParkSession {
    $creds = $Vals

    if($null -eq $creds){
        Write-Host "No creds found!!"
        return $null;
    }
    Write-Host "Getting Login Form"

    $urlencodedEmail = [System.Web.HttpUtility]::UrlEncode($creds.email)
    $urlencodedPass = [System.Web.HttpUtility]::UrlEncode($creds.pass)

    $Uri = "${BaseUri}/Account/Login"

    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get -SessionVariable session
    $ReqVerification = GetReqVerToken($WebResp.Content)

    Write-Host "Getting session"
    $Body = "__RequestVerificationToken=${ReqVerification}&Email=${urlencodedEmail}&Password=${urlencodedPass}"
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Post `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    return $session
}

function UbiParkBook {
    [CmdletBinding()]
    param([Microsoft.PowerShell.Commands.WebRequestSession]$session, [String]$Date)

    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting Booking Form"
    $Uri = "${BaseUri}/BookNow"
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method Get `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session
    $ReqVerification = GetReqVerToken($WebResp.Content)

    Write-Host "Making a Booking Request"
    $Uri = "${BaseUri}/BookNow/Payment"
    $From = "${Date}T07%3A00%3A00.000"
    $To = "${Date}T19%3A15%3A00.000"
    $Body = "Group=teammember&SelectedCarParkName=&RateGroupID=70&Hourly=True&ToDateDisplay=True&LicensePlateDisplay=True&FromDate=${From}&ToDate=${To}&PaymentGatewayID=1&PromoCodeID=&PromoCodeOneTimeUseID=&PromoCode=&DiscountPermitID=&CaptureNumberPlateRequired=True&NumberPlateRequiredRequired=True&MaxPurchaseDays=21&CustomTextDisplay=False&CustomTextRequired=False&CustomTextLabel=&CarParkID=${CarParkID}&FromDatePicker=27%2F05%2F2022&FromTimePicker=09%3A00&ToDatePicker=27%2F05%2F2022&ToTimePicker=09%3A15&LicensePlate_input=${NumberPlate}&LicensePlate=${NumberPlate}&CountryID=1&StateID=1&__RequestVerificationToken=${ReqVerification}&X-Requested-With=XMLHttpRequest"


    $PaymentResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    $ReqVerification = GetReqVerToken($PaymentResp.Content)
    
    Write-Host "Getting booking details"
    $StationBayReservedID = GetFormData $PaymentResp.Content "StationBayReservedID"
    $StationBayID = GetFormData $PaymentResp.Content "StationBayID"
    $CardToken = GetFormData $PaymentResp.Content "CardToken"
    $BayLabel = "" #(GetFormData $WebResp.Content "BayLabel").Replace(" ","+")
    
    if($StationBayReservedID -eq "404"){
        return "Parking failed for $Date"
    }    
    Write-Host "Confirming the Booking"
    $Uri = "${BaseUri}/BookNow/ProcessPayment"
    $Body = "Group=teammember&UserPermitID=0&UserID=134525&PermitID=196&PermitName=Botanicca+Car+Park&CarParkID=${CarParkID}&CarParkName=National+Support+Office+-+Botanicca+3&EffectiveFrom=${From}&EffectiveTo=${To}&Hourly=True&LicensePlate=${NumberPlate}&CountryID=1&StateID=1&StateCode=&PaymentAmount=0&PaymentGatewayID=1&CardToken=${CardToken}&HasCard=False&ReservedBays=True&ChangeBay=True&StationBayReservedID=${StationBayReservedID}&StationBayID=${StationBayID}&BayLabel=${BayLabel}&BayNotes=&TandemBayID=&PromoCodeID=&PromoCodeOneTimeUseID=&PromoCode=&DiscountPermitID=&Cost=0&Discount=0&CustomText=&__RequestVerificationToken=${ReqVerification}"

    # Write-Verbose $Body.Replace("&","`r`n")
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body
    
    return "Parking reserved for $Date"
}

function UbiParkCancel ([Microsoft.PowerShell.Commands.WebRequestSession]$session, [String]$Date){
    if($null -eq $session){
        Write-Host "No session!"
        return
    }
    Write-Host "Getting bookings"
    $Uri = "${BaseUri}/UserPermit/Read?HistoricalItems=False"
    $Body = "sort=&page=1&pageSize=500&group=&filter=EffectiveTo~lte~datetime'${Date}T23-00-00'~and~EffectiveFrom~gte~datetime'${Date}T00-00-00'"
    
    $WebResp = Invoke-WebRequest `
                -Uri $Uri `
                -Method POST `
                -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                -WebSession $session `
                -Body $Body

    $Bookings = $WebResp.Content | ConvertFrom-Json
    $BookingID = $Bookings.Data[0].ID
    
    if($null -ne $BookingID){

        $Uri = "${BaseUri}/UserPermit/CancelPermit?id=${BookingID}"
        Write-Host "Requesting cancellation form $Uri"
        $WebResp = Invoke-WebRequest `
                    -Uri $Uri `
                    -Method Get `
                    -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                    -WebSession $session
    
        Write-Host "Cancelling Booking"
        $ReqVerification = GetReqVerToken($WebResp.Content)
        $Body = "__RequestVerificationToken=${ReqVerification}&UserPermitID=${BookingID}"
        $WebResp = Invoke-WebRequest `
                    -Uri $Uri `
                    -Method Post `
                    -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
                    -WebSession $session `
                    -Body $Body 
        Write-Host "Your Booking has been cancelled and a confirmation has been emailed"
    }
}


$Date = "2022-06-23"

$Vals = GetUbiParkVals
$BaseUri = $Vals.baseUri
$CarParkID = $Vals.carParkID
$NumberPlate = $Vals.numberPlate
$session = GetUbiParkSession

UbiParkBook $session $Date
# UbiParkCancel $session $Date