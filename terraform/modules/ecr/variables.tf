variable "name" {
  description = "Repository name."
  type        = string
}

variable "keep_last_images" {
  description = "Older images are expired. Keep enough to roll back to."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
