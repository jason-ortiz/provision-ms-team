<# Copyright (c) Microsoft Corporation. All rights reserved.
   This code is licensed under the Microsoft Public License.
   THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
   ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
   IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
   PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT. #>

Param
(
    [Parameter (Mandatory=$true)]
    [String] $UPN,
    [Parameter (Mandatory=$true)]
    [String] $GroupId   
)
$ErrorActionPreference = "Stop"

# Establish connection to Microsoft Teams
$cred = Get-AutomationPSCredential -Name "WorkflowService" # Service Account = Team Creator
Connect-MicrosoftTeams -Credential $cred

# Create new Microsoft Team
Write-Output "Create new Team using existing O365 Group"
$team = New-Team -Group $GroupId
$team

<# If Team Creator isn't the user requesting this Team, then remove Team Creator as owner
   from Team and add requesting user as owner instead #>
if ($cred.UserName -ne $UPN) {
    # Connect to Azure AD with service principal aka Azure Run as Account
    $servicePrincipal = Get-AutomationConnection -Name 'AzureRunAsConnection'
    Connect-AzureAD -ApplicationId $servicePrincipal.ApplicationId `
                    -TenantId $servicePrincipal.TenantId `
                    -CertificateThumbprint $servicePrincipal.CertificateThumbprint

    # Add requesting user to Team as owner
    $user = Get-AzureADUser -Filter "UserPrincipalName eq '$($UPN)' or Mail eq '$($UPN)'"
    Write-Output "Add requesting user as Group Owner"
    Add-AzureADGroupOwner -ObjectId $team.GroupId -RefObjectId $user.ObjectId

    # Try removing Team Creator as owner from Team
    $creator = Get-AzureADUser -Filter "UserPrincipalName eq '$($cred.UserName)'"
    Write-Output "Remove Team Creator as Group Owner"
    Remove-AzureADGroupOwner -ObjectId $team.GroupId -OwnerId $creator.ObjectId

    Disconnect-AzureAD
}
Disconnect-MicrosoftTeams
