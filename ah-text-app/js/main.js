"use strict";

/**
 * American History Archive — main.js
 *
 * The site is served via CloudFront + OAC from a private S3 bucket.
 * All requests — including the app ZIP download — go through CloudFront.
 * The S3 bucket is never accessed directly.
 *
 * Replace CLOUDFRONT_DOMAIN with your actual distribution domain
 * before deploying. Everything else is handled by CloudFront.
 */

const CLOUDFRONT_DOMAIN = "youramericanhistory.click";

const DOWNLOAD_PATH = "/app_placeholder.zip";

document.addEventListener("DOMContentLoaded", function () {
  const btn = document.querySelector(".download-btn");

  if (!btn) return;

  btn.setAttribute("href", "https://" + CLOUDFRONT_DOMAIN + DOWNLOAD_PATH);
});
