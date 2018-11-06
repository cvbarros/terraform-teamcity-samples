variable "github_organization" {
  description = "Name of github organization"
}

variable "github_repository" {
  description = "Name of the application repository without org name (Not the Github URL)"
}

variable "project_name" {
  description = "Friendly name for the project in TeamCity"
}

variable "project_description" {
  description = "Friendly description for project in TeamCity"
}

variable "github_auth_username" {
  description = "Username to connect to Github"
}

variable "github_auth_password" {
  description = "Password to connect to Github"
}
