# Seeds are not used for production bootstrapping.
# To set up the first site and admin, use:
#
#   bin/rails cms:sites:create -- --slug=... --name=... --repo-url=... \
#     --branch=main --site-url=... --publish-author="Name <email>"
#
# Then in the Rails console:
#   user = User.create!(email_address: 'you@example.com', password: 'changeme', display_name: 'Your Name')
#   Membership.create!(user: user, site: Site.last, role: 'admin')
#
# See README.md for the full setup walkthrough.
