(() => {
  const header = document.querySelector('[data-header]');
  const nav = document.querySelector('[data-nav]');
  const toggle = document.querySelector('[data-nav-toggle]');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const syncHeader = () => header?.classList.toggle('scrolled', window.scrollY > 24);
  syncHeader();
  window.addEventListener('scroll', syncHeader, { passive: true });

  toggle?.addEventListener('click', () => {
    const open = nav?.classList.toggle('open') ?? false;
    toggle.setAttribute('aria-expanded', String(open));
  });
  nav?.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => {
    nav.classList.remove('open');
    toggle?.setAttribute('aria-expanded', 'false');
  }));

  const reveal = document.querySelectorAll('[data-reveal]');
  if (reducedMotion || !('IntersectionObserver' in window)) {
    reveal.forEach((element) => element.classList.add('revealed'));
  } else {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px' });
    reveal.forEach((element) => observer.observe(element));
  }

  document.querySelectorAll('[data-stage]').forEach((button) => {
    button.addEventListener('click', () => {
      document.querySelectorAll('[data-stage]').forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
    });
  });

  document.querySelectorAll('[data-year]').forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
