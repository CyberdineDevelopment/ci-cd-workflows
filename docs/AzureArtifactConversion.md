# GitHub Actions to Azure Pipelines Migration Guide for .NET CI/CD

## Migration from GitHub Actions to Azure DevOps

This comprehensive guide covers migrating a complex .NET CI/CD workflow from GitHub Actions to Azure Pipelines, maintaining all functionality while leveraging Azure DevOps capabilities.

### Key Architecture Differences

**GitHub Actions → Azure Pipelines Mapping:**
- `on:` triggers → `trigger:` and `pr:`
- `runs-on:` → `pool: vmImage:`
- `uses:` actions → `task:` or `script:`
- GitHub secrets → Azure Key Vault + Variable Groups
- GitHub environments → Azure Pipelines environments with approval gates
- Marketplace actions → Azure DevOps marketplace extensions or built-in tasks

## Complete Azure Pipeline Implementation

### Master Pipeline Configuration

```yaml
# azure-pipelines.yml
name: .NET-CI-CD-$(Date:yyyyMMdd)$(Rev:.r)

parameters:
- name: environment
  displayName: 'Target Environment'
  type: string
  default: 'development'
  values:
  - development
  - staging
  - production
- name: runSecurityScans
  displayName: 'Run Security Scans'
  type: boolean
  default: true

trigger:
  branches:
    include:
    - main
    - master
    - develop
    - release/*
    - feature/*
  tags:
    include:
    - v*
    - release-*
  paths:
    exclude:
    - docs/*
    - '*.md'

pr:
  branches:
    include:
    - main
    - develop
  autoCancel: true

schedules:
- cron: "0 2 * * *"
  displayName: Daily Security Scan
  branches:
    include:
    - main
    - develop
  always: true
- cron: "0 8 * * 1"
  displayName: Weekly Deep Security Analysis
  branches:
    include:
    - main
    - release/*
  always: true

variables:
  buildConfiguration: 'Release'
  NUGET_PACKAGES: $(Pipeline.Workspace)/.nuget/packages
  dotnetVersions: '9.0.x,10.0.x'
  
# Variable groups based on branch
- ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
  - group: 'production-secrets'
- ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/develop') }}:
  - group: 'development-secrets'
- ${{ if startsWith(variables['Build.SourceBranch'], 'refs/heads/release/') }}:
  - group: 'staging-secrets'

stages:
- stage: Version
  displayName: 'Semantic Versioning with nbgv'
  jobs:
  - job: SetVersion
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: self
      fetchDepth: 0  # Required for nbgv
    
    - task: DotNetCoreCLI@2
      displayName: 'Install nbgv tool'
      inputs:
        command: 'custom'
        custom: 'tool'
        arguments: 'install --tool-path . nbgv --ignore-failed-sources'
    
    - script: |
        ./nbgv cloud -c -a
        echo "##vso[build.updatebuildnumber]$(GitBuildVersion)"
      displayName: 'Set Version Variables'

- stage: Build
  displayName: 'Build and Test'
  dependsOn: Version
  jobs:
  - job: BuildMatrix
    strategy:
      matrix:
        NET9:
          dotnetVersion: '9.0.x'
        NET10:
          dotnetVersion: '10.0.x'
      maxParallel: 2
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    # .NET SDK Installation
    - task: UseDotNet@2
      displayName: 'Install .NET $(dotnetVersion)'
      inputs:
        packageType: 'sdk'
        version: $(dotnetVersion)
        performMultiLevelLookup: true
        includePreviewVersions: true
    
    # NuGet Cache
    - task: Cache@2
      displayName: 'Cache NuGet packages'
      inputs:
        key: 'nuget | "$(Agent.OS)" | **/packages.lock.json,!**/bin/**,!**/obj/**'
        restoreKeys: |
          nuget | "$(Agent.OS)"
          nuget
        path: '$(NUGET_PACKAGES)'
        cacheHitVar: 'CACHE_RESTORED'
    
    # Azure Artifacts Authentication
    - task: NuGetAuthenticate@1
      displayName: 'Authenticate with Azure Artifacts'
    
    # Restore
    - task: DotNetCoreCLI@2
      displayName: 'Restore packages'
      condition: ne(variables.CACHE_RESTORED, true)
      inputs:
        command: 'restore'
        projects: '**/*.csproj'
        feedsToUse: 'config'
        nugetConfigPath: 'nuget.config'
    
    # Build
    - task: DotNetCoreCLI@2
      displayName: 'Build solution'
      inputs:
        command: 'build'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildConfiguration) --no-restore'
    
    # Test with Code Coverage
    - task: DotNetCoreCLI@2
      displayName: 'Run unit tests'
      inputs:
        command: 'test'
        projects: '**/*Test*.csproj'
        arguments: '--configuration $(buildConfiguration) --no-build --collect:"XPlat Code Coverage" --logger trx'
        publishTestResults: true
    
    # Publish Code Coverage
    - task: PublishCodeCoverageResults@1
      displayName: 'Publish code coverage'
      inputs:
        codeCoverageTool: 'Cobertura'
        summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'

- stage: SecurityScanning
  displayName: 'Security Scanning'
  dependsOn: Build
  condition: and(succeeded(), eq('${{ parameters.runSecurityScans }}', 'true'))
  jobs:
  - job: CodeQLScan
    displayName: 'GitHub Advanced Security - CodeQL Analysis'
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    # Initialize CodeQL
    - task: AdvancedSecurity-Codeql-Init@1
      displayName: 'Initialize CodeQL'
      inputs:
        languages: 'csharp'
        querysuite: 'security-and-quality'
        
    # Build for CodeQL Analysis
    - task: DotNetCoreCLI@2
      displayName: 'Build for CodeQL'
      inputs:
        command: 'build'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildConfiguration)'
    
    # Perform CodeQL Analysis
    - task: AdvancedSecurity-Codeql-Analyze@1
      displayName: 'Perform CodeQL Analysis'
    
    # Dependency Scanning
    - task: AdvancedSecurity-Dependency-Scanning@1
      displayName: 'GitHub Advanced Security Dependency Scanning'
      
  - job: AdditionalSecurityScans
    displayName: 'Additional Security Scanning'
    pool:
      vmImage: 'windows-latest'
    steps:
    # Microsoft Security DevOps (complementary scanning)
    - task: MicrosoftSecurityDevOps@1
      displayName: 'Microsoft Security DevOps Scan'
      inputs:
        policy: 'microsoft'
        categories: 'artifacts,IaC,containers'
        break: true
    
    # NuGet Vulnerability Scanning
    - script: |
        dotnet list package --vulnerable --include-transitive 2>&1 | tee nuget-vulnerabilities.log
        if grep -q -i "critical\|high" nuget-vulnerabilities.log; then
          echo "##vso[task.logissue type=error]Critical vulnerabilities found"
          exit 1
        fi
      displayName: 'NuGet Vulnerability Check'
    
    # OWASP Dependency Check
    - task: dependency-check-build-task@6
      displayName: 'OWASP Dependency Check'
      inputs:
        projectName: '$(Build.Repository.Name)'
        scanPath: '$(System.DefaultWorkingDirectory)'
        format: 'ALL'
        nvdApiKey: $(NVD_API_KEY)
        failBuildOnCVSS: 7
    
    # Container Scanning with Trivy
    - script: |
        mkdir -p $(Build.ArtifactStagingDirectory)/trivy
        docker run --rm -v $(System.DefaultWorkingDirectory):/root/src:ro aquasec/trivy:latest fs --scanners vuln --format sarif --output /root/src/trivy-results.sarif /root/src
        cp $(System.DefaultWorkingDirectory)/trivy-results.sarif $(Build.ArtifactStagingDirectory)/trivy/
      displayName: 'Trivy Security Scan'
    
    # SBOM Generation with CycloneDX
    - task: CmdLine@2
      displayName: 'Install CycloneDX'
      inputs:
        script: 'dotnet tool install --global CycloneDX'
    
    - script: |
        dotnet CycloneDX $(System.DefaultWorkingDirectory) --json --output $(Build.ArtifactStagingDirectory)/sbom
      displayName: 'Generate SBOM with CycloneDX'
    
    # Publish Security Artifacts
    - task: PublishBuildArtifacts@1
      displayName: 'Publish Security Reports'
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'security-reports'

- stage: Package
  displayName: 'Package and Publish'
  dependsOn: 
  - Build
  - SecurityScanning
  condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
  jobs:
  - job: PackageArtifacts
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    # Key Vault Integration
    - task: AzureKeyVault@2
      displayName: 'Get secrets from Key Vault'
      inputs:
        azureSubscription: 'azure-service-connection'
        KeyVaultName: '$(keyVaultName)'
        SecretsFilter: 'nuget-api-key,internal-feed-pat'
        RunAsPreJob: false
    
    # Pack NuGet packages
    - task: DotNetCoreCLI@2
      displayName: 'Pack NuGet packages'
      inputs:
        command: 'pack'
        packagesToPack: '**/*.csproj;!**/*Test*.csproj'
        versioningScheme: 'byEnvVar'
        versionEnvVar: 'GitBuildVersion'
        packDirectory: '$(Build.ArtifactStagingDirectory)/packages'
        includesymbols: true
        includesource: true
    
    # Publish to Azure Artifacts (Internal Feed)
    - task: DotNetCoreCLI@2
      displayName: 'Push to Internal Feed'
      inputs:
        command: 'push'
        packagesToPush: '$(Build.ArtifactStagingDirectory)/packages/*.nupkg'
        nuGetFeedType: 'internal'
        publishVstsFeed: 'my-project/my-feed'
        allowPackageConflicts: false
    
    # Conditional NuGet.org Publishing
    - task: NuGetCommand@2
      displayName: 'Push to NuGet.org'
      condition: and(succeeded(), or(eq(variables['Build.SourceBranch'], 'refs/heads/main'), startsWith(variables['Build.SourceBranch'], 'refs/tags/v')))
      inputs:
        command: 'push'
        packagesToPush: '$(Build.ArtifactStagingDirectory)/packages/*.nupkg;!$(Build.ArtifactStagingDirectory)/packages/*.symbols.nupkg'
        nuGetFeedType: 'external'
        publishFeedCredentials: 'nuget-org-connection'

- stage: Deploy
  displayName: 'Deploy to ${{ parameters.environment }}'
  dependsOn: Package
  condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
  jobs:
  - deployment: DeployApplication
    environment: ${{ parameters.environment }}
    pool:
      vmImage: 'ubuntu-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureKeyVault@2
            displayName: 'Get deployment secrets'
            inputs:
              azureSubscription: 'azure-service-connection'
              KeyVaultName: '${{ parameters.environment }}-keyvault'
              SecretsFilter: '*'
          
          # Your deployment steps here
          - script: |
              echo "Deploying to ${{ parameters.environment }}"
              echo "Using connection string from Key Vault"
            displayName: 'Deploy application'
```

### Supporting Configuration Files

#### security-scan-template.yml
```yaml
# templates/security-scan-template.yml
parameters:
- name: scanLevel
  type: string
  default: 'standard'
  values:
  - quick
  - standard
  - deep
- name: breakOnHighVulnerabilities
  type: boolean
  default: true

jobs:
- job: GitHubAdvancedSecurity
  displayName: 'GitHub Advanced Security Scanning'
  pool:
    vmImage: 'ubuntu-latest'
  steps:
  # CodeQL Analysis
  - task: AdvancedSecurity-Codeql-Init@1
    displayName: 'Initialize CodeQL - ${{ parameters.scanLevel }}'
    inputs:
      languages: 'csharp'
      querysuite: ${{ if eq(parameters.scanLevel, 'deep') }}${{ 'security-extended' }}${{ else }}${{ 'security-and-quality' }}
      
  - task: DotNetCoreCLI@2
    displayName: 'Build for CodeQL Analysis'
    inputs:
      command: 'build'
      projects: '**/*.csproj'
      arguments: '--configuration Release'
      
  - task: AdvancedSecurity-Codeql-Analyze@1
    displayName: 'Perform CodeQL Analysis'
    inputs:
      uploadResults: true
      checkBreakBuild: ${{ parameters.breakOnHighVulnerabilities }}
      
  # Dependency Scanning
  - task: AdvancedSecurity-Dependency-Scanning@1
    displayName: 'Dependency Vulnerability Scanning'
    inputs:
      scanDirectory: '$(Build.SourcesDirectory)'
      breakOnHighVulnerabilities: ${{ parameters.breakOnHighVulnerabilities }}
      
  # Secret Scanning
  - task: AdvancedSecurity-Secret-Scanning@1
    displayName: 'Secret Detection Scanning'
    inputs:
      scanDirectory: '$(Build.SourcesDirectory)'
      includeHistory: ${{ if eq(parameters.scanLevel, 'deep') }}${{ true }}${{ else }}${{ false }}
      
  # Generate Security Report
  - task: AdvancedSecurity-Report@1
    displayName: 'Generate Security Report'
    inputs:
      reportFormat: 'html,sarif,json'
      outputDirectory: '$(Build.ArtifactStagingDirectory)/security-reports'
      includeSuppressed: false
      
  - task: PublishBuildArtifacts@1
    displayName: 'Publish Security Reports'
    inputs:
      PathtoPublish: '$(Build.ArtifactStagingDirectory)/security-reports'
      ArtifactName: 'security-reports-$(Build.BuildId)'
```

#### version.json (for nbgv)
```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "1.0-alpha",
  "assemblyVersion": {
    "precision": "major.minor"
  },
  "publicReleaseRefSpec": [
    "^refs/heads/main$",
    "^refs/heads/master$",
    "^refs/heads/release/.*$"
  ],
  "nugetPackageVersion": {
    "semVer": 2
  },
  "cloudBuild": {
    "buildNumber": {
      "enabled": true
    },
    "setVersionVariables": true,
    "setAllVariables": true
  },
  "release": {
    "firstUnstableTag": "alpha",
    "branchName": "release/v{version}",
    "tagFormat": "v{version}",
    "versionIncrement": "minor"
  }
}
```

#### nuget.config
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="MyInternalFeed" value="https://pkgs.dev.azure.com/{org}/{project}/_packaging/{feed}/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <MyInternalFeed>
      <add key="Username" value="any" />
      <add key="ClearTextPassword" value="%NUGET_AUTH_TOKEN%" />
    </MyInternalFeed>
  </packageSourceCredentials>
</configuration>
```

## Key Migration Components

### 1. Azure Artifacts Setup
- Create feeds for different environments (development, staging, production)
- Configure upstream sources to include nuget.org
- Set retention policies (100-500 versions per package)
- Implement proper authentication using service connections

### 2. Azure Key Vault Integration
- Create separate Key Vaults for each environment
- Store all sensitive data (API keys, connection strings, certificates)
- Link Variable Groups to Key Vaults
- Use service principal authentication with minimal required permissions

### 3. Security Scanning Tools
- **GitHub Advanced Security for Azure DevOps with CodeQL**: Enterprise-grade code scanning
  - CodeQL semantic code analysis for vulnerability detection
  - Secret scanning across repositories
  - Dependency scanning for known vulnerabilities
  - SARIF format results integrated into Azure DevOps UI
- **Microsoft Security DevOps**: Complementary security tools integration
- **OWASP Dependency Check**: Additional vulnerability scanning
- **Trivy**: Container and filesystem vulnerability scanning
- **CycloneDX**: SBOM generation in multiple formats

### 4. nbgv Semantic Versioning
- Automatic version calculation from Git history
- Branch-specific versioning (alpha for develop, beta for release branches)
- Integration with Azure Artifacts for package versioning
- Support for git-flow branching strategy

### 5. Deployment Strategies
- **Environments**: Separate dev, staging, and production with approval gates
- **Blue-Green**: For zero-downtime deployments
- **Canary**: For gradual rollouts with traffic splitting
- **Rolling**: For high-availability services

### 6. Service Connections
- Azure Resource Manager for Key Vault access
- NuGet for external package feeds
- Docker Registry for container deployments
- Generic connections for third-party services

## Azure DevOps Specific Optimizations

### 1. Pipeline Caching
```yaml
# Advanced caching strategy
- task: Cache@2
  inputs:
    key: 'nuget | "$(Agent.OS)" | $(Build.SourcesDirectory)/**/packages.lock.json'
    restoreKeys: |
      nuget | "$(Agent.OS)"
    path: '$(NUGET_PACKAGES)'
```

### 2. Parallel Jobs
```yaml
# Matrix strategy for multi-version builds
strategy:
  matrix:
    NET9_Windows:
      vmImage: 'windows-latest'
      dotnetVersion: '9.0.x'
    NET9_Linux:
      vmImage: 'ubuntu-latest'
      dotnetVersion: '9.0.x'
    NET10_Linux:
      vmImage: 'ubuntu-latest'
      dotnetVersion: '10.0.x'
  maxParallel: 3
```

### 3. Template Reusability
Create reusable templates for common tasks:
```yaml
# templates/security-scan.yml
parameters:
- name: scanType
  type: string
  default: 'full'

steps:
- task: MicrosoftSecurityDevOps@1
  displayName: 'Security Scan - ${{ parameters.scanType }}'
  inputs:
    policy: 'microsoft'
    categories: ${{ parameters.scanType }}
```

### 4. Environment-Specific Deployments
```yaml
# Conditional deployment based on branch
- ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
  - template: templates/deploy-production.yml
- ${{ elseif startsWith(variables['Build.SourceBranch'], 'refs/heads/release/') }}:
  - template: templates/deploy-staging.yml
- ${{ else }}:
  - template: templates/deploy-development.yml
```

## GitHub Advanced Security for Azure DevOps Configuration

### Prerequisites
1. GitHub Advanced Security license for Azure DevOps
2. Project Collection Administrator or Project Administrator permissions
3. Build service account needs appropriate permissions

### Setup Steps

#### 1. Enable GitHub Advanced Security
```bash
# At organization level
az devops admin banner update --id "GitHubAdvancedSecurity" --enabled true

# At project level
# Navigate to Project Settings > GitHub Advanced Security > Enable
```

#### 2. Configure CodeQL Analysis
Create a `.github/codeql/codeql-config.yml` file:
```yaml
name: "CodeQL config"
queries:
  - uses: security-extended
  - uses: security-and-quality
paths-ignore:
  - '**/bin/**'
  - '**/obj/**'
  - '**/packages/**'
  - '**/*.min.js'
  - '**/node_modules/**'
  - '**/migrations/**'
```

#### 3. Custom CodeQL Queries
For .NET-specific security patterns:
```yaml
# .azuredevops/security/custom-queries.yml
- task: AdvancedSecurity-Codeql-Init@1
  inputs:
    languages: 'csharp'
    querysuite: 'security-extended'
    additionalQueries: |
      - uses: ./queries/sql-injection-dotnet.ql
      - uses: ./queries/hardcoded-secrets.ql
      - uses: ./queries/insecure-deserialization.ql
```

#### 4. Secret Scanning Configuration
Configure custom patterns in repository settings:
```json
{
  "customPatterns": [
    {
      "name": "Azure Storage Key",
      "pattern": "DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=[A-Za-z0-9+/]{86}==",
      "allowlist": ["test", "example", "demo"]
    },
    {
      "name": "Azure Service Bus Connection",
      "pattern": "Endpoint=sb://[^;]+\\.servicebus\\.windows\\.net/;SharedAccessKeyName=[^;]+;SharedAccessKey=[^;]+",
      "allowlist": []
    }
  ]
}
```

#### 5. Integration with Pull Requests
```yaml
# PR validation pipeline snippet
- task: AdvancedSecurity-Codeql-Init@1
  displayName: 'Initialize CodeQL'
  condition: eq(variables['Build.Reason'], 'PullRequest')
  inputs:
    languages: 'csharp'
    querysuite: 'security-and-quality'
    
# After build
- task: AdvancedSecurity-Codeql-Analyze@1
  displayName: 'Perform CodeQL Analysis'
  inputs:
    uploadResults: true
    checkForPolicyViolations: true
```

### Viewing and Managing Results

#### Security Tab Features:
1. **Code scanning alerts**: View and manage CodeQL findings
2. **Secret scanning alerts**: Track exposed secrets
3. **Dependency scanning alerts**: Known vulnerabilities in dependencies
4. **Alert suppression**: Dismiss false positives with justification
5. **SARIF file uploads**: Import results from other tools

#### Alert Management:
```yaml
# Suppress false positives in code
// codeql[cs/sql-injection] - This is parameterized query, false positive
var result = await connection.QueryAsync<User>(sql, parameters);

# Or in pipeline
- task: AdvancedSecurity-CodeQL-Autobuild@1
  env:
    CODEQL_DISABLE_RULES: 'cs/hardcoded-credentials,cs/cleartext-storage'
```

### Best Practices for GitHub Advanced Security

1. **Incremental Adoption**
   - Start with security-only queries
   - Gradually add quality queries
   - Custom queries for business logic

2. **Performance Optimization**
   ```yaml
   - task: AdvancedSecurity-Codeql-Init@1
     inputs:
       ram: 8192  # Increase RAM for large codebases
       threads: 4  # Parallel analysis
       addProjectDirToScanningExclusionList: true
   ```

3. **Branch Protection**
   ```yaml
   # Branch policies
   - Require CodeQL checks to pass
   - No high/critical vulnerabilities
   - Secret scanning clear
   - Dependencies up to date
   ```

4. **Reporting and Metrics**
   ```yaml
   # Export security findings
   - task: AdvancedSecurity-Export@1
     inputs:
       exportType: 'sarif'
       outputPath: '$(Build.ArtifactStagingDirectory)/security'
       includeSupressed: false
   ```

## Migration Checklist

1. **Infrastructure Setup**
   - [ ] Create Azure DevOps project and repositories
   - [ ] Set up Azure Key Vaults for each environment
   - [ ] Configure service principals and RBAC
   - [ ] Create Azure Artifacts feeds

2. **Pipeline Configuration**
   - [ ] Convert GitHub Actions workflows to Azure Pipelines YAML
   - [ ] Set up branch triggers and PR validation
   - [ ] Configure scheduled security scans
   - [ ] Implement nbgv for semantic versioning

3. **Security Implementation**
   - [ ] Enable GitHub Advanced Security at organization/project level
   - [ ] Configure CodeQL with appropriate query suites
   - [ ] Set up custom secret scanning patterns
   - [ ] Configure branch protection policies with security gates
   - [ ] Install Microsoft Security DevOps extension
   - [ ] Configure OWASP Dependency Check
   - [ ] Set up container scanning with Trivy
   - [ ] Implement SBOM generation
   - [ ] Configure security alerting and notifications

4. **Deployment Setup**
   - [ ] Create environments with approval gates
   - [ ] Configure deployment strategies
   - [ ] Set up service connections
   - [ ] Test rollback procedures

5. **Testing and Validation**
   - [ ] Verify all build configurations work
   - [ ] Test security scanning catches known vulnerabilities
   - [ ] Validate deployment to all environments
   - [ ] Ensure proper secret management

This migration provides equivalent or superior functionality to your GitHub Actions workflow while leveraging Azure DevOps's enterprise features for enhanced security, scalability, and integration with the Microsoft ecosystem.