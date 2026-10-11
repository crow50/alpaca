variable "iso_url" {
  type        = string
  description = "18.04.6 only ships a live-server (Subiquity) ISO, which this preseed.cfg doesn't target -- 18.04.5 is the last point release with the classic debian-installer server ISO this build expects."
  default     = "http://old-releases.ubuntu.com/releases/18.04.5/ubuntu-18.04.5-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"
}
