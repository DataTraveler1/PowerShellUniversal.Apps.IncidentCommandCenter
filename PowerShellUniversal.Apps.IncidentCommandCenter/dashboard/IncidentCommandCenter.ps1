New-UDApp -Title 'Acme Inc. | Incident Command Center' -Content {
    New-UDStyle -Style $Cache:IccShowcaseCss -Content {
        New-UDElement -Tag 'div' -Attributes @{ className = 'icc-shell' } -Content {
            New-UDDynamic -Id 'icc-desk' -Content {
                Import-Module (Join-Path $Cache:IccShowcaseModuleRoot 'PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
                $exercise = Get-IccDemoExercise
                $Session:IccExerciseId = $exercise.ExerciseId
                New-UDHtml -Markup (Get-IccDemoView -Exercise $exercise -Section Overview)
                New-UDElement -Tag 'section' -Attributes @{ className = 'icc-action-panel'; 'aria-label' = 'Incident actions' } -Content {
                    New-UDElement -Tag 'div' -Attributes @{ className = 'icc-action-copy' } -Content {
                        New-UDElement -Tag 'strong' -Content { 'Take the next safe step' }
                        New-UDElement -Tag 'span' -Content { 'Acme demo controls. Ready when you are.' }
                    }
                    New-UDElement -Tag 'div' -Attributes @{ className = 'icc-actions' } -Content {
                        $ackLabel = if ($exercise.State.incidentStatus -ceq 'Acknowledged') { 'Repeat acknowledgment' } else { 'Acknowledge incident' }
                        New-UDButton -Id 'icc-acknowledge' -Text $ackLabel -Variant 'contained' -Color 'primary' -OnClick {
                            Import-Module (Join-Path $Cache:IccShowcaseModuleRoot 'PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
                            try {
                                $result = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $Session:IccExerciseId -RequireCurrent
                                $message = if ($result.Events[-1].disposition -ceq 'AlreadyAcknowledged') { 'Already acknowledged. The original saved state is unchanged.' } else { 'Incident acknowledged. The warning remains visible.' }
                                Show-UDToast -Message $message -Duration 5000
                                Sync-UDElement -Id 'icc-desk'
                            } catch { Show-UDToast -Message ('Action could not complete: ' + $_.Exception.Message) -Duration 8000 }
                        }
                        New-UDButton -Id 'icc-verify' -Text 'Verify saved state' -Variant 'outlined' -OnClick {
                            Import-Module (Join-Path $Cache:IccShowcaseModuleRoot 'PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
                            try {
                                $null = Invoke-IccDemoAction -Action Read -ExerciseId $Session:IccExerciseId -RequireCurrent
                                Show-UDToast -Message 'A separate read loaded the saved state from disk.' -Duration 5000
                                Sync-UDElement -Id 'icc-desk'
                            } catch { Show-UDToast -Message ('Read could not complete: ' + $_.Exception.Message) -Duration 8000 }
                        }
                        New-UDButton -Id 'icc-handoff' -Text 'Create handoff 📋' -Variant 'outlined' -OnClick {
                            Import-Module (Join-Path $Cache:IccShowcaseModuleRoot 'PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
                            try {
                                $requestedId = $Session:IccExerciseId
                                $Session:IccHandoffText = Get-IccDemoHandoff -ExerciseId $requestedId -RequireCurrent
                                $Session:IccHandoffExerciseId = $requestedId
                                Sync-UDElement -Id 'icc-desk'
                                Show-UDModal -Header { New-UDTypography -Text 'Ready for the next operator' -Variant h5 } -Content {
                                    New-UDTypography -Text 'Select and copy this summary into your shift notes.' -Variant body2
                                    New-UDHtml -Markup ('<pre style="white-space:pre-wrap;font:14px/1.7 Segoe UI,sans-serif;padding:18px;background:#f3f6f9;border-radius:12px;user-select:text">' + [Net.WebUtility]::HtmlEncode($Session:IccHandoffText) + '</pre>')
                                } -Footer { New-UDButton -Text 'Close' -OnClick { Hide-UDModal } } -FullWidth -MaxWidth 'md'
                            } catch { Show-UDToast -Message ('Handoff could not complete: ' + $_.Exception.Message) -Duration 8000 }
                        }
                        New-UDButton -Id 'icc-new' -Text 'New rehearsal' -Variant 'text' -OnClick {
                            Import-Module (Join-Path $Cache:IccShowcaseModuleRoot 'PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
                            try {
                                $null = New-IccDemoExercise
                                Show-UDToast -Message 'Fresh rehearsal ready. Previous exercises are retained.' -Duration 5000
                                Sync-UDElement -Id 'icc-desk'
                            } catch { Show-UDToast -Message ('Rehearsal could not start: ' + $_.Exception.Message) -Duration 8000 }
                        }
                    }
                }
                New-UDHtml -Markup (Get-IccDemoView -Exercise $exercise -Section Details -HandoffPrepared:($Session:IccHandoffExerciseId -ceq $exercise.ExerciseId))
            }
        }
    }
}
