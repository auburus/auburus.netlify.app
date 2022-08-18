
help:
    @just -l

    
# Build the static site
build:
    just clean

    hugo
    cd public && zip -r public.zip .
    mv public/public.zip ./public.zip

# Start a dev server
dev:
    xdg-open http://localhost:1313
    hugo server
    rm -r resources

# Deploy the site
deploy:
    curl \
        --fail \
        -H "Content-Type: application/zip" \
        -H "Authorization: Bearer ${NETLIFY_TOKEN}" \
        --data-binary "@public.zip" \
        https://api.netlify.com/api/v1/sites/auburus.netlify.app/deploys

# Load the site in a browser window
prod:
    xdg-open https://auburus.netlify.app
    
# Remove autogenerated artifacts
clean:
    rm -rf \
        public \
        public.zip \
        resources
