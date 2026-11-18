# Architecture - Hybrid Bank Ghana
[ Mobile App ] -> [ ALB ] -> [ EKS Mobile API ] -> [ RDS Mobile-Only ]
EKS -> [ VGW ] == VPN Tunnel 1 + 2 == [ CGW Accra ] -> [ Core Banking 192.168.0.0/16 - Stays On-Prem ]
Future: Direct Connect 1Gbps via Accra MSA (not provisioned)
