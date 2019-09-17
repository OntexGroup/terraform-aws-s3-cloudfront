variable "env" {}

variable "aws" {
  type    = any
  default = {}
}

variable "dns" {
  type    = any
  default = {}
}

variable "front" {
  type    = any
  default = {}
}

variable "custom_tags" {
  type    = map
  default = {}
}

variable "project" {
  default = ""
}
