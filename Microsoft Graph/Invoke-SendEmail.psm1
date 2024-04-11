<#
.SYNOPSIS
    Sends an email using Microsoft Graph API.
.DESCRIPTION
    This function sends an email using Microsoft Graph API. The function constructs the email message and sends it to the specified recipients.
.PARAMETER accessToken
    Required: The access token to authenticate the request.
.PARAMETER subject
    Required: The subject of the email.
.PARAMETER body
    Required: The body of the email.
.PARAMETER recipients
    Required: An array of email addresses of the recipients.
.PARAMETER fromAddress
    Required: The email address of the sender.
.PARAMETER attachmentPath
    Optional: The path to the attachment file.
.PARAMETER ccRecipients
    Optional: An array of email addresses of the CC recipients.
.PARAMETER bccRecipients
    Optional: An array of email addresses of the BCC recipients.
.PARAMETER dueDate
    Optional: The due date of the email in the format "yyyy-MM-ddTHH:mm:ssZ".
.PARAMETER startDate
    Optional: The start date of the email in the format "yyyy-MM-ddTHH:mm:ssZ".
.PARAMETER timeZone
    Optional: The time zone of the email.
.NOTES
    The access token requires permission to send mail on behalf of the sender. For application permissions, the permission required is "Mail.Send".
    For more information, see https://docs.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http.
    Author: Timothy Alexander
    https://github.com/taalexander0614/CtrlAltUpgrade
.EXAMPLE
    # This example sends an email to the specified recipients, with an attachment and flagged for follow-up with a start date of the current date and a due date of tomorrow.
    # Get-AccessToken is an internal function we use to get access tokens.
    $authToken = Get-AccessToken -tenantID $tenantID -appID $appID -appSecret $appSecret
    
    # Required
    $accessToken = $authToken.access_token
    $fromAddress = "noreply@ctrlaltupgrade.com"
    $subject = "Test Email"
    $body = "This is a test email."
    $recipients = @(
        "user1@ctrlaltupgrade.com"
    )

    # Optional
    $ccRecipients = @(
        "user2@ctrlaltupgrade.com"
    )
    $bccRecipients = @(
        "user3@ctrlaltupgrade.com"
    )
    $attachmentPath = "C:\path\to\attachment.txt"
    $startDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dueDate = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $timeZone = "Eastern Standard Time"

    $response = Invoke-SendEmail -accessToken $accessToken -dueDate $dueDate -subject $subject -body $body -recipients $recipients -fromAddress $fromAddress
#>

function Invoke-SendEmail {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$accessToken,
            [Parameter(Mandatory = $true)]
            [string]$subject,
            [Parameter(Mandatory = $true)]
            [string]$body,
            [Parameter(Mandatory = $true)]
            [array]$recipients,
            [Parameter(Mandatory = $true)]
            [string]$fromAddress,
            [Parameter(Mandatory = $false)]
            [string]$attachmentPath,
            [Parameter(Mandatory = $false)]
            [array]$ccRecipients,
            [Parameter(Mandatory = $false)]
            [array]$bccRecipients,
            [Parameter(Mandatory = $false)]
            [string]$dueDate, # $dueDate and $startDate should be in the format "yyyy-MM-ddTHH:mm:ssZ"
            [Parameter(Mandatory = $false)]
            [string]$startDate,
            [Parameter(Mandatory = $false)]
            [string]$timeZone
        )
    
        try {
            $uri = "https://graph.microsoft.com/v1.0/users/$fromAddress/sendMail"
            $headers = @{
                "Content-Type" = "application/json"
                "Authorization" = "Bearer $accessToken"
            }
            # Construct the email message
            $emailBody = @{
                message = @{
                    subject = $subject
                    body = @{
                        contentType = "Text"
                        content = $body
                    }
                    toRecipients = @(
                        $recipients | ForEach-Object {
                            @{
                                emailAddress = @{
                                    address = $_
                                }
                            }
                        }
                    )
                }
            }
    
            # Add CC recipients if provided
            if ($ccRecipients) {
                $emailBody["message"]["ccRecipients"] = @(
                    $ccRecipients | ForEach-Object {
                        @{
                            emailAddress = @{
                                address = $_
                            }
                        }
                    }
                )
            }
    
            # Add BCC recipients if provided
            if ($bccRecipients) {
                $emailBody["message"]["bccRecipients"] = @(
                    $bccRecipients | ForEach-Object {
                        @{
                            emailAddress = @{
                                address = $_
                            }
                        }
                    }
                )
            }
    
            # Add flag headers if startDate and dueDate are provided in $flagged PSCustomObject parameter
            if ($dueDate) {
                # Use the current timezone if not provided
                if (-not $timeZone) {
                    $timeZone = (Get-TimeZone).Id
                }
                if (-not $startDate) {
                    $startDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                $emailBody["message"]["flag"] = @{
                    flagStatus = "flagged"
                    startDateTime = @{
                        dateTime = $startDate
                        timeZone = $timeZone
                    }
                    dueDateTime = @{
                        dateTime = $dueDate
                        timeZone = $timeZone
                    }
                }
            }
            
            # Check if attachmentPath is provided
            if ($attachmentPath) {
                if (Test-Path $attachmentPath) {
                    $attachmentName = [System.IO.Path]::GetFileName($attachmentPath)
                    $attachmentSize = (Get-Item $attachmentPath).length
                    if ($attachmentSize -gt 3MB) {
                        $body += "`n`nAttachment '$attachmentName' is too large to send ($attachmentSize byte). Max size is 3MB."
                    }
                    else {
                        $attachmentName = (Get-Item $attachmentPath).Name
                        $attachmentContent = [Convert]::ToBase64String([IO.File]::ReadAllBytes($attachmentPath))
                        # Add attachment to email body
                        $emailBody["message"]["attachments"] = @(
                            @{
                                "@odata.type" = "#microsoft.graph.fileAttachment"
                                "name" = $attachmentName
                                "contentBytes" = $attachmentContent
                            }
                        )
                    }
                }
            }    
    
            $convertedEmailBody = $emailBody | ConvertTo-Json -Depth 10
            $emailResponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $convertedEmailBody -ErrorAction Stop
            return $emailResponse
        }
        catch {
            Write-Host "Error: $_"
            throw $_
        }
    }