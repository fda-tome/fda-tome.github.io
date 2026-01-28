document.addEventListener("DOMContentLoaded", function () {
  var anchors = document.querySelectorAll("a[href]");
  var origin = window.location.origin;
  anchors.forEach(function (a) {
    var href = a.getAttribute("href");
    if (!href) return;
    if (
      href.startsWith("#") ||
      href.startsWith("mailto:") ||
      href.startsWith("tel:") ||
      href.startsWith("javascript:")
    ) {
      return;
    }

    var url;
    try {
      url = new URL(href, window.location.href);
    } catch (e) {
      return;
    }

    if (url.origin !== origin) {
      if (!a.target) a.target = "_blank";
      var rel = (a.getAttribute("rel") || "")
        .split(/\s+/)
        .filter(Boolean);
      if (rel.indexOf("noopener") === -1) rel.push("noopener");
      if (rel.indexOf("noreferrer") === -1) rel.push("noreferrer");
      a.setAttribute("rel", rel.join(" "));
    }
  });
});
