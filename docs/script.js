"use strict";

document.documentElement.classList.add("js");
const navToggle = document.querySelector(".nav-toggle");
const siteNav = document.getElementById("site-nav");
function closeMenu() {
  siteNav.classList.remove("is-open");
  navToggle.setAttribute("aria-expanded", "false");
  navToggle.setAttribute("aria-label", "Open menu");
}
if (navToggle && siteNav) {
  navToggle.hidden = false;
  navToggle.addEventListener("click", () => {
    const open = siteNav.classList.toggle("is-open");
    navToggle.setAttribute("aria-expanded", String(open));
    navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  });
  siteNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      const wasOpen = siteNav.classList.contains("is-open");
      closeMenu();
      if (wasOpen) navToggle.focus();
    }
  });
}

document.querySelectorAll("[data-year]").forEach((node) => {
  node.textContent = String(new Date().getFullYear());
});

// Static download links remain usable without JavaScript or GitHub API access.
const repository = "emp0ry/IsaacExternalItemDescriptionsiOS";
const latest = `https://github.com/${repository}/releases/latest`;
function releaseURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === "github.com" &&
      url.pathname.startsWith(`/${repository}/releases/`) ? url.href : null;
  } catch {
    return null;
  }
}
async function loadRelease() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" }, signal: controller.signal,
    });
    if (!response.ok) throw new Error(`GitHub API returned ${response.status}`);
    const release = await response.json();
    const releaseLink = releaseURL(release.html_url) || latest;
    const assets = new Map((release.assets || []).map((asset) => [asset.name, releaseURL(asset.browser_download_url)]));
    document.querySelectorAll("[data-asset]").forEach((link) => {
      const asset = assets.get(link.dataset.asset);
      link.href = asset || releaseLink;
      if (!asset) link.textContent = "Open release ↗";
    });
    document.querySelectorAll("[data-release-link]").forEach((link) => { link.href = releaseLink; });
    if (typeof release.tag_name === "string") {
      document.querySelectorAll("[data-version]").forEach((node) => { node.textContent = release.tag_name; });
    }
    const status = document.querySelector("[data-release-status]");
    if (status) status.textContent = `${release.name || release.tag_name || "Latest release"} · Available on GitHub`;
  } catch {
    const status = document.querySelector("[data-release-status]");
    if (status) status.textContent = "Latest release and checksums are available on GitHub";
  } finally {
    clearTimeout(timeout);
  }
}
loadRelease();

const toolbar = document.querySelector(".gallery-toolbar");
const screenshots = [...document.querySelectorAll(".screenshot-card")];
if (toolbar) {
  toolbar.hidden = false;
  toolbar.querySelectorAll("[data-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      toolbar.querySelectorAll("[data-filter]").forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
      let count = 0;
      screenshots.forEach((card) => {
        card.hidden = button.dataset.filter !== "all" && card.dataset.category !== button.dataset.filter;
        if (!card.hidden) count += 1;
      });
      document.querySelector(".gallery-count").textContent = count + (count === 1 ? " screenshot" : " screenshots");
    });
  });
}
const lightbox = document.querySelector(".lightbox");
if (lightbox && typeof lightbox.showModal === "function") {
  const image = lightbox.querySelector("img");
  const caption = lightbox.querySelector(".lightbox-caption");
  const original = lightbox.querySelector(".lightbox-original");
  let trigger = null;
  document.querySelectorAll("[data-lightbox]").forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();
      trigger = link;
      image.src = link.href;
      image.alt = link.querySelector("img").alt;
      caption.textContent = image.alt;
      original.href = link.href;
      lightbox.showModal();
    });
  });
  lightbox.querySelector(".lightbox-close").addEventListener("click", () => lightbox.close());
  lightbox.addEventListener("click", (event) => {
    if (event.target !== lightbox) return;
    const bounds = lightbox.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) lightbox.close();
  });
  lightbox.addEventListener("close", () => { if (trigger) trigger.focus({preventScroll: true}); });
}
