locals {
  effective_certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : aws_acm_certificate_validation.wildcard[0].certificate_arn
}

resource "aws_acm_certificate" "wildcard" {
  count = var.acm_certificate_arn == "" ? 1 : 0

  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.acm_certificate_arn == "" && var.manage_route53_records && var.route53_zone_id != "" ? {
    for dvo in aws_acm_certificate.wildcard[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  count = var.acm_certificate_arn == "" ? 1 : 0

  certificate_arn = aws_acm_certificate.wildcard[0].arn
  validation_record_fqdns = var.manage_route53_records && var.route53_zone_id != "" ? [
    for record in aws_route53_record.cert_validation : record.fqdn
  ] : []
}

resource "aws_route53_record" "e2b_routing" {
  count = var.manage_route53_records && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "e2b.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.ingress.dns_name
    zone_id                = aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "nomad_routing" {
  count = var.manage_route53_records && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "nomad.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.ingress.dns_name
    zone_id                = aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}
