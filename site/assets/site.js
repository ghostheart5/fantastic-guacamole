const header = document.querySelector('.site-header');
if (header) {
  const updateHeader = () => header.dataset.scrolled = String(window.scrollY > 8);
  updateHeader();
  window.addEventListener('scroll', updateHeader, { passive: true });
}
