// Language switching
function setLang(lang) {
    // Update buttons
    document.getElementById('btn-zh').classList.toggle('active', lang === 'zh');
    document.getElementById('btn-en').classList.toggle('active', lang === 'en');
    
    // Update all elements with data-zh and data-en attributes
    document.querySelectorAll('[data-zh][data-en]').forEach(el => {
        el.innerHTML = el.getAttribute('data-' + lang);
    });
    
    // Update html lang attribute
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : 'en';
    
    // Save preference
    localStorage.setItem('preferred-lang', lang);
}

// Load saved language preference
document.addEventListener('DOMContentLoaded', () => {
    const savedLang = localStorage.getItem('preferred-lang');
    if (savedLang) {
        setLang(savedLang);
    }
});
