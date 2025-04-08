if exists('g:loaded_aws') | finish | endif
let g:loaded_aws = 1

if has('nvim')
  command! -nargs=? -complete=customlist,s:aws_profile_completion AWSConsole terminal fzf-aws-console <args>
  command! AWSLogin terminal aws sso login
else
  command! -nargs=? -complete=customlist,s:aws_profile_completion AWSConsole terminal ++hidden ++close fzf-aws-console <args>
  command! AWSLogin terminal ++close aws sso login
endif

function! s:amazon_q(args, line_start, line_end, count, mods) range
  let cmd = 'terminal q chat'
  let args = [a:args]->filter('v:val != ""')
  let formatted_string = ''
  if !empty(args)
    if a:count > -1
      let lines = getline(a:line_start, a:line_end)
      call add(args, ":")
      call add(args, lines)
    endif
    let formatted_string = flatten(args)->join(' ')->escape('"')->escape('%')->escape('#')
    let cmd = printf(cmd .. ' "%s"', formatted_string)
  endif
  exe a:mods .. ' ' .. cmd
endfunction
command! -nargs=? -range -complete=file_in_path Q call s:amazon_q(<q-args>, <line1>, <line2>, <count>, <q-mods>)

" Completion for AWS
function! s:aws_completion(A,L,P) abort
  let l:cmdline_list = split(a:L[:a:P-1], '\%(\%(\%(^\|[^\\]\)\\\)\@<!\s\)\+')
  if index(l:cmdline_list[-2:], '--profile') >= 0
    return call('s:aws_profile_completion', [a:A, a:L, a:P])
  else
    return call('s:aws_command_completion', [a:A, a:L, a:P])
  endif
endfunction

" Completion for AWS commands
function! s:aws_command_completion(A,L,P) abort
  return [
        \ '--ca-bundle', '--cli-connect-timeout', '--debug', '--no-cli-pager', '--no-verify-ssl', '--query',
        \ '--cli-auto-prompt', '--cli-read-timeout', '--endpoint-url', '--no-paginate', '--output', '--region',
        \ '--cli-binary-format', '--color', '--no-cli-auto-prompt', '--no-sign-request', '--profile', '--version',
        \ 'accessanalyzer', 'account', 'acm', 'acm-pca', 'alexaforbusiness', 'amp', 'amplify', 'amplifybackend', 'amplifyuibuilder', 'apigateway', 'apigatewaymanagementapi', 'apigatewayv2', 'appconfig', 'appconfigdata', 'appfabric', 'appflow', 'appintegrations', 'application-autoscaling', 'application-insights', 'applicationcostprofiler', 'appmesh', 'apprunner', 'appstream', 'appsync', 'arc-zonal-shift', 'athena', 'auditmanager', 'autoscaling', 'autoscaling-plans',
        \ 'backup', 'backup-gateway', 'backupstorage', 'batch', 'billingconductor', 'braket', 'budgets',
        \ 'ce', 'chime', 'chime-sdk-identity', 'chime-sdk-media-pipelines', 'chime-sdk-meetings', 'chime-sdk-messaging', 'chime-sdk-voice', 'cleanrooms', 'cloud9', 'cloudcontrol', 'clouddirectory', 'cloudformation', 'cloudfront', 'cloudhsm', 'cloudhsmv2', 'cloudsearch', 'cloudsearchdomain', 'cloudtrail', 'cloudtrail-data', 'cloudwatch', 'codeartifact', 'codebuild', 'codecatalyst', 'codecommit', 'codeguru-reviewer', 'codeguru-security', 'codeguruprofiler', 'codepipeline', 'codestar', 'codestar-connections', 'codestar-notifications', 'cognito-identity', 'cognito-idp', 'cognito-sync', 'comprehend', 'comprehendmedical', 'compute-optimizer', 'connect', 'connect-contact-lens', 'connectcampaigns', 'connectcases', 'connectparticipant', 'controltower', 'cur', 'customer-profiles', 'cli-dev', 'configservice', 'configure',
        \ 'databrew', 'dataexchange', 'datapipeline', 'datasync', 'dax', 'detective', 'devicefarm', 'devops-guru', 'directconnect', 'discovery', 'dlm', 'dms', 'docdb', 'docdb-elastic', 'drs', 'ds', 'dynamodb', 'dynamodbstreams', 'ddb', 'deploy',
        \ 'ebs', 'ec2', 'ec2-instance-connect', 'ecr', 'ecr-public', 'ecs', 'efs', 'eks', 'elastic-inference', 'elasticache', 'elasticbeanstalk', 'elastictranscoder', 'elb', 'elbv2', 'emr', 'emr-containers', 'emr-serverless', 'entityresolution', 'es', 'events', 'evidently',
        \ 'finspace', 'finspace-data', 'firehose', 'fis', 'fms', 'forecast', 'forecastquery', 'frauddetector', 'fsx',
        \ 'gamelift', 'gamesparks', 'glacier', 'globalaccelerator', 'glue', 'grafana', 'greengrass', 'greengrassv2', 'groundstation', 'guardduty',
        \ 'health', 'healthlake', 'honeycode', 'help', 'history',
        \ 'iam', 'identitystore', 'imagebuilder', 'importexport', 'inspector', 'inspector2', 'internetmonitor', 'iot', 'iot-data', 'iot-jobs-data', 'iot-roborunner', 'iot1click-devices', 'iot1click-projects', 'iotanalytics', 'iotdeviceadvisor', 'iotevents', 'iotevents-data', 'iotfleethub', 'iotfleetwise', 'iotsecuretunneling', 'iotsitewise', 'iotthingsgraph', 'iottwinmaker', 'iotwireless', 'ivs', 'ivs-realtime', 'ivschat',
        \ 'kafka', 'kafkaconnect', 'kendra', 'kendra-ranking', 'keyspaces', 'kinesis', 'kinesis-video-archived-media', 'kinesis-video-media', 'kinesis-video-signaling', 'kinesis-video-webrtc-storage', 'kinesisanalytics', 'kinesisanalyticsv2', 'kinesisvideo', 'kms',
        \ 'lakeformation', 'lambda', 'lex-models', 'lex-runtime', 'lexv2-models', 'lexv2-runtime', 'license-manager', 'license-manager-linux-subscriptions', 'license-manager-user-subscriptions', 'lightsail', 'location', 'logs', 'lookoutequipment', 'lookoutmetrics', 'lookoutvision',
        \ 'm2', 'machinelearning', 'macie', 'macie2', 'managedblockchain', 'managedblockchain-query', 'marketplace-catalog', 'marketplace-entitlement', 'marketplacecommerceanalytics', 'mediaconnect', 'mediaconvert', 'medialive', 'mediapackage', 'mediapackage-vod', 'mediapackagev2', 'mediastore', 'mediastore-data', 'mediatailor', 'medical-imaging', 'memorydb', 'meteringmarketplace', 'mgh', 'mgn', 'migration-hub-refactor-spaces', 'migrationhub-config', 'migrationhuborchestrator', 'migrationhubstrategy', 'mobile', 'mq', 'mturk', 'mwaa',
        \ 'neptune', 'neptunedata', 'network-firewall', 'networkmanager', 'nimble',
        \ 'oam', 'omics', 'opensearch', 'opensearchserverless', 'opsworks', 'opsworkscm', 'organizations', 'osis', 'outposts', 'opsworks-cm',
        \ 'panorama', 'payment-cryptography', 'payment-cryptography-data', 'pca-connector-ad', 'personalize', 'personalize-events', 'personalize-runtime', 'pi', 'pinpoint', 'pinpoint-email', 'pinpoint-sms-voice', 'pinpoint-sms-voice-v2', 'pipes', 'polly', 'pricing', 'privatenetworks', 'proton',
        \ 'qldb', 'qldb-session', 'quicksight',
        \ 'ram', 'rbin', 'rds', 'rds-data', 'redshift', 'redshift-data', 'redshift-serverless', 'rekognition', 'resiliencehub', 'resource-explorer-2', 'resource-groups', 'resourcegroupstaggingapi', 'robomaker', 'rolesanywhere', 'route53', 'route53-recovery-cluster', 'route53-recovery-control-config', 'route53-recovery-readiness', 'route53domains', 'route53resolver', 'rum',
        \ 's3control', 's3outposts', 'sagemaker', 'sagemaker-a2i-runtime', 'sagemaker-edge', 'sagemaker-featurestore-runtime', 'sagemaker-geospatial', 'sagemaker-metrics', 'sagemaker-runtime', 'savingsplans', 'scheduler', 'schemas', 'sdb', 'secretsmanager', 'securityhub', 'securitylake', 'serverlessrepo', 'service-quotas', 'servicecatalog', 'servicecatalog-appregistry', 'servicediscovery', 'ses', 'sesv2', 'shield', 'signer', 'simspaceweaver', 'sms', 'snow-device-management', 'snowball', 'sns', 'sqs', 'ssm', 'ssm-contacts', 'ssm-incidents', 'ssm-sap', 'sso', 'sso-admin', 'sso-oidc', 'stepfunctions', 'storagegateway', 'sts', 'support', 'support-app', 'swf', 'synthetics', 's3api', 's3',
        \ 'textract', 'timestream-query', 'timestream-write', 'tnb', 'transcribe', 'transfer', 'translate',
        \ 'verifiedpermissions', 'voice-id', 'vpc-lattice',
        \ 'waf', 'waf-regional', 'wafv2', 'wellarchitected', 'wisdom', 'workdocs', 'worklink', 'workmail', 'workmailmessageflow', 'workspaces', 'workspaces-web',
        \ 'xray',
        \ ]->filter('v:val =~ a:A')
endfunction

" Completion for AWS `--profile`
function! s:aws_profile_completion(A,L,P) abort
  return systemlist('aws configure list-profiles')->filter('v:val =~ a:A')
endfunction

command! -nargs=* -complete=customlist,s:aws_completion AWS
      \ terminal awe --no-cli-pager --cli-auto-prompt <args>

command! -nargs=* -complete=customlist,s:aws_profile_completion AWSProfile
      \ terminal awe --no-cli-pager --cli-auto-prompt --profile <args>
