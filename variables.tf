variable "Source_Bucket_Name" {
  type = string
}

variable "Destination_Bucket" {
  type = list(string)
}

variable "Destination_Filter" {
  type = list(string)
}

variable "Versioning" {
  type = string
}

