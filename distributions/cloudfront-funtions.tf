resource "aws_cloudfront_function" "headers" {
  name    = "${replace(local.primary_domain, ".", "-")}-headers"
  runtime = "cloudfront-js-2.0"
  comment = "Add security headers and handle clean URLs"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Add .html extension if no file extension
    if (!uri.includes('.')) {
        request.uri = uri + '.html';
    }
    
    // Handle directory index
    if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    }
    
    return request;
}
EOT
}

resource "aws_cloudfront_function" "security_headers" {
  name    = "${replace(local.primary_domain, ".", "-")}-security"
  runtime = "cloudfront-js-2.0"
  comment = "Add security headers to responses"
  publish = true
  code    = <<-EOT
function handler(event) {
    var response = event.response;
    var headers = response.headers;
    
    headers['strict-transport-security'] = { value: 'max-age=63072000; includeSubdomains; preload' };
    headers['x-content-type-options'] = { value: 'nosniff' };
    headers['x-frame-options'] = { value: 'DENY' };
    headers['x-xss-protection'] = { value: '1; mode=block' };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    
    return response;
}
EOT
}