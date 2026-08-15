using './main.bicep'

param location = 'uksouth'
param projectName = 'commercefabric'

param githubDeploymentPrincipalId = '69c7550b-04c2-4334-af5c-5bd8de684f8f'

// Don't paste a private key here.
// This must be the contents of the corresponding .pub file.
param aksSshPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMmlcz4HGu1POee31MBP1bCK6VtcyEPgiqtomwYp7MSUtxBMGoXR6wG5+WTHP8GfSurL6/QHXVZPrKzFQDQxv4u2edeRjNSr+ZezfYXbSkPOMchKTfMfazw8TpCSvriHalyfwR2uW4ZJsEh1piHLCL6122NiUCUOjZ1BXKONJXdeILV1tJVEVbiqjcgc+DHCe529pJX1PqjJVOXTcBAoc1HlhidaKosBESC2MdtWACzD292dV4XUYGSU1pUhEEoaR/bLOF5pV8mZnP9N517Kes1acrYeIDIhDVo733N9YeSqUBTTAdrPnzuyHcCtQR1Nt/th3ExjTKh9R8nJYxHVuT'
