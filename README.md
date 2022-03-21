# This script will help you find the plugin that is causing issues on your WordPress site.
# The script will divide and deactivate the active plugins in batches of half until the problematic plugin is found. This is significantly faster as opposed to disabling the plugins one-by-one (especially if there are 10+ active plugins).

# KEY FEATURES:
# It creates a backup of the WordPress database, but it is also recommended to use this script on a staging environment.
# It allows you to skip any of the active plugins (e.g. in case you want to keep WooCommerce active).
# It automatically clears the WordPress cache after each batch is deactivated and will continue to run until the problematic plugin is found.

# USAGE
# It is recommended to run the script in the root folder of the WordPress site.
# The script requires WP-CLI.
