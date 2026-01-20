{{- /*
Resolve Slack channel for AlertmanagerConfig.

Priority:
1) receiver.channel from values (explicit override)
2) read from K8s Secret (populated by ESO): <secretName>/<secretKey>
3) if not found, return empty string (so template can omit channel field)

*/ -}}
{{- define "alerting.slackChannel" -}}
{{- $ns := (.Values.alerting.namespace | default "monitoring") -}}
{{- $secretName := (.Values.alerting.slack.channelSecret.name | default "alertmanager-secrets") -}}
{{- $secretKey := (.Values.alerting.slack.channelSecret.key | default "SLACK_CHANNEL") -}}

{{- $s := (lookup "v1" "Secret" $ns $secretName) -}}
{{- if and $s $s.data (hasKey $s.data $secretKey) -}}
{{- (index $s.data $secretKey | b64dec) -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}
