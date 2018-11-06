provider "teamcity" {
  version = "0.4"
}

resource "teamcity_project" "project" {
  name = "${var.project_name}"
  description = "${var.project_description}"

  config_params = {
    verbosity = "minimal"
  }

  env_params = {
    TEAMCITY_ARTIFACT_PASSWORD = "%system.teamcity.auth.password%"
    TEAMCITY_ARTIFACT_USER = "%system.teamcity.auth.userId%"
    TEAMCITY_BUILD_ID = "%teamcity.build.id%"
  }
}

resource "teamcity_vcs_root_git" "project_vcs_root" {
  name = "${var.github_repository}"
  project_id = "${teamcity_project.project.id}"

  fetch_url = "https://github.com/${var.github_organization}/${var.github_repository}"

  default_branch = "master"
  branches = ["+:refs/(pull/*)/head"]

  agent {
    clean_files_policy = "untracked"
    clean_policy = "branch_change"
    use_mirrors = true
  }

  username_style = "author_email"

  auth {
    type = "userpass"
    username = "${var.github_auth_username}"
    password = "${var.github_auth_password}"
  }
}

resource "teamcity_build_config" "pullrequest" {
  name = "1. Pull Request"
  description = "Inspection Build with \"pullrequest\" target"
  project_id = "${teamcity_project.project.id}"

  settings {
    build_number_format = "1.0.%build.counter%"
    concurrent_limit = 10
  }
  step {
    type = "powershell"
    name = "Invoke build.ps1 with 'pullrequest' target"
    file = "build.ps1"
    args = "-Target pullrequest -Verbosity %verbosity%"
  }
  vcs_root {
    id  = "${teamcity_vcs_root_git.project_vcs_root.id}"
  }
}

resource "teamcity_build_trigger_vcs" "pullrequest_vcs_trigger" {
  build_config_id = "${teamcity_build_config.pullrequest.id}"

  rules = "+:*"
  branch_filter = "+:pull/*"
}

resource "teamcity_feature_commit_status_publisher" "github_publish" {
	build_config_id = "${teamcity_build_config.pullrequest.id}"
	publisher = "github"
	github {
		auth_type = "password"
		host = "https://api.github.com"
		username = "${var.github_auth_username}"
		password = "${var.github_auth_password}"
	}
}

resource "teamcity_build_config" "buildrelease" {
  name = "2. Build Release"
  description = "Build new release with \"buildrelease\" target"
  project_id = "${teamcity_project.project.id}"

  settings {
    build_number_format = "1.0.%build.counter%"
  }
  step {
    type = "powershell"
    name = "Invoke build.ps1 with 'buildrelease' target"
    file = "build.ps1"
    args = "-Target buildrelease -Verbosity %verbosity%"
  }
  vcs_root {
    id  = "${teamcity_vcs_root_git.project_vcs_root.id}"
  }
}

resource "teamcity_build_trigger_vcs" "buildrelease_vcs_trigger" {
  build_config_id = "${teamcity_build_config.buildrelease.id}"

  rules = "+:*"
  branch_filter = "+:pull/*"
}

resource "teamcity_build_config" "release_testing" {
  name = "3. Release To Testing"
  description = "Deploys and validates a release to Testing environment"
  project_id = "${teamcity_project.project.id}"

  settings {
    build_number_format = "%env.RELEASE_VERSION%"
  }
  step {
    type = "powershell"
    name = "Invoke build.ps1 with 'release' target"
    file = "build.ps1"
    args = "-Target release -Verbosity %verbosity%"
  }

  env_params {
    ARTIFACTS_ROOT_URL = "%dep.${teamcity_build_config.buildrelease.id}.env.ARTIFACTS_ROOT_URL%"
    RELEASE_ENVIRONMENT = "Testing"
    RELEASE_VERSION = "%dep.${teamcity_build_config.buildrelease.id}.env.RELEASE_VERSION%"
  }
  vcs_root {
    id  = "${teamcity_vcs_root_git.project_vcs_root.id}"
  }
}

resource "teamcity_build_config" "release_acceptance" {
  name = "4. Release To Acceptance"
  description = "Deploys and validates a release to Acceptance environment"
  project_id = "${teamcity_project.project.id}"

  settings {
    build_number_format = "%env.RELEASE_VERSION%"
  }
  step {
    type = "powershell"
    name = "Invoke build.ps1 with 'release' target"
    file = "build.ps1"
    args = "-Target release -Verbosity %verbosity%"
  }

  env_params {
    ARTIFACTS_ROOT_URL = "%dep.${teamcity_build_config.buildrelease.id}.env.ARTIFACTS_ROOT_URL%"
    RELEASE_ENVIRONMENT = "Acceptance"
    RELEASE_VERSION = "%dep.${teamcity_build_config.buildrelease.id}.env.RELEASE_VERSION%"
  }
  vcs_root {
    id  = "${teamcity_vcs_root_git.project_vcs_root.id}"
  }
}

resource "teamcity_build_config" "release_production" {
  name = "5. Release To Production"
  description = "Deploys and validates a release to Production environment"
  project_id = "${teamcity_project.project.id}"

  settings {
    build_number_format = "%env.RELEASE_VERSION%"
  }
  step {
    type = "powershell"
    name = "Invoke build.ps1 with 'release' target"
    file = "build.ps1"
    args = "-Target release -Verbosity %verbosity%"
  }

  env_params {
    ARTIFACTS_ROOT_URL = "%dep.${teamcity_build_config.buildrelease.id}.env.ARTIFACTS_ROOT_URL%"
    RELEASE_ENVIRONMENT = "Production"
    RELEASE_VERSION = "%dep.${teamcity_build_config.buildrelease.id}.env.RELEASE_VERSION%"
  }
  vcs_root {
    id  = "${teamcity_vcs_root_git.project_vcs_root.id}"
  }
}

################################################################################
# Build Chains
################################################################################
resource "teamcity_build_trigger_build_finish" "testing_finish_trigger" {
  build_config_id = "${teamcity_build_config.release_testing.id}"
  source_build_config_id = "${teamcity_build_config.buildrelease.id}"

  after_successful_only = true
  branch_filter = ["+:<default>"]
}

resource "teamcity_snapshot_dependency" "release_testing" {
  build_config_id        = "${teamcity_build_config.release_testing.id}"
  source_build_config_id = "${teamcity_build_config.buildrelease.id}"
}

resource "teamcity_agent_requirement" "testing_env_req" {
  build_config_id = "${teamcity_build_config.release_testing.id}"
  condition = "equals"
  name = "teamcity.agent.env"
  value = "testing"
}

resource "teamcity_build_trigger_build_finish" "acceptance_finish_trigger" {
  build_config_id = "${teamcity_build_config.release_acceptance.id}"
  source_build_config_id = "${teamcity_build_config.release_testing.id}"

  after_successful_only = true
  branch_filter = ["+:<default>"]
}

resource "teamcity_snapshot_dependency" "release_acceptance" {
  build_config_id        = "${teamcity_build_config.release_acceptance.id}"
  source_build_config_id = "${teamcity_build_config.release_testing.id}"
}

resource "teamcity_agent_requirement" "acceptance_env_req" {
  build_config_id = "${teamcity_build_config.release_acceptance.id}"
  condition = "equals"
  name = "teamcity.agent.env"
  value = "acceptance"
}

resource "teamcity_snapshot_dependency" "release_production" {
  build_config_id        = "${teamcity_build_config.release_production.id}"
  source_build_config_id = "${teamcity_build_config.release_acceptance.id}"
}

resource "teamcity_agent_requirement" "production_env_req" {
  build_config_id = "${teamcity_build_config.release_production.id}"
  condition = "equals"
  name = "teamcity.agent.env"
  value = "production"
}
