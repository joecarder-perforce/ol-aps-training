resource "aws_lb" "api" {
  name               = "${var.cluster}-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = [for s in aws_subnet.private : s.id] # your private subnets
  enable_cross_zone_load_balancing = true
  tags = { Cluster = var.cluster, Role = "nlb-api" }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.cluster}-tg-api"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.cluster.id
  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_target_group" "mcs" {
  name        = "${var.cluster}-tg-mcs"
  port        = 22623
  protocol    = "TCP"
  vpc_id      = aws_vpc.cluster.id
  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "api_6443" {
  load_balancer_arn = aws_lb.api.arn
  port              = 6443
  protocol          = "TCP"
  default_action { type = "forward", target_group_arn = aws_lb_target_group.api.arn }
}

resource "aws_lb_listener" "mcs_22623" {
  load_balancer_arn = aws_lb.api.arn
  port              = 22623
  protocol          = "TCP"
  default_action { type = "forward", target_group_arn = aws_lb_target_group.mcs.arn }
}

# --- Attachments ---
# Masters → API & MCS
resource "aws_lb_target_group_attachment" "api_masters" {
  for_each         = { for i in aws_instance.master : i.id => i }
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = each.key
  port             = 6443
}

resource "aws_lb_target_group_attachment" "mcs_masters" {
  for_each         = { for i in aws_instance.master : i.id => i }
  target_group_arn = aws_lb_target_group.mcs.arn
  target_id        = each.key
  port             = 22623
}

# Bootstrap → MCS only
resource "aws_lb_target_group_attachment" "mcs_bootstrap" {
  target_group_arn = aws_lb_target_group.mcs.arn
  target_id        = aws_instance.bootstrap.id
  port             = 22623
}
