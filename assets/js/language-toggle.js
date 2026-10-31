// Universal Language Toggle Script for FocusBro Documentation
// This script ensures language toggle works on all pages

(function() {
    'use strict';
    
    console.log('🌐 Universal Language Toggle: Loading...');
    
    // Language toggle functionality
    function initUniversalLanguageToggle() {
        console.log('🔧 Universal Language Toggle: Initializing...');
        
        const langButtons = document.querySelectorAll('.lang-btn');
        console.log('📝 Found language buttons:', langButtons.length);
        
        if (langButtons.length === 0) {
            console.warn('⚠️ No language buttons found on this page');
            return;
        }
        
        // Remove any existing event listeners to prevent conflicts
        langButtons.forEach(btn => {
            const newBtn = btn.cloneNode(true);
            btn.parentNode.replaceChild(newBtn, btn);
        });
        
        // Get fresh references after cloning
        const freshLangButtons = document.querySelectorAll('.lang-btn');
        
        freshLangButtons.forEach(btn => {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                const lang = this.getAttribute('data-lang');
                console.log('🔄 Language button clicked:', lang);
                
                if (!lang) {
                    console.error('❌ No language attribute found');
                    return;
                }
                
                switchToLanguage(lang);
            });
        });
        
        console.log('✅ Universal Language Toggle: Event listeners attached');
    }
    
    function switchToLanguage(lang) {
        console.log('🌐 Switching to language:', lang);
        
        try {
            // Update active button state
            const langButtons = document.querySelectorAll('.lang-btn');
            langButtons.forEach(btn => {
                btn.classList.remove('active');
                if (btn.getAttribute('data-lang') === lang) {
                    btn.classList.add('active');
                }
            });
            
            // Find all translatable elements
            const elements = document.querySelectorAll('[data-en]');
            console.log('📝 Found translatable elements:', elements.length);
            
            let updatedCount = 0;
            elements.forEach((element, index) => {
                const enText = element.getAttribute('data-en');
                const idText = element.getAttribute('data-id');
                
                if (lang === 'en' && enText) {
                    element.textContent = enText;
                    updatedCount++;
                } else if (lang === 'id' && idText) {
                    element.textContent = idText;
                    updatedCount++;
                }
            });
            
            // Update page title
            const titleElement = document.querySelector('title');
            if (titleElement) {
                const enTitle = titleElement.getAttribute('data-en');
                const idTitle = titleElement.getAttribute('data-id');
                
                if (lang === 'en' && enTitle) {
                    titleElement.textContent = enTitle;
                } else if (lang === 'id' && idTitle) {
                    titleElement.textContent = idTitle;
                }
            }
            
            // Update meta description
            const metaDesc = document.querySelector('meta[name="description"]');
            if (metaDesc) {
                const enDesc = metaDesc.getAttribute('data-en');
                const idDesc = metaDesc.getAttribute('data-id');
                
                if (lang === 'en' && enDesc) {
                    metaDesc.setAttribute('content', enDesc);
                } else if (lang === 'id' && idDesc) {
                    metaDesc.setAttribute('content', idDesc);
                }
            }
            
            // Update search placeholder if exists
            const searchInput = document.getElementById('site-search');
            if (searchInput) {
                if (lang === 'id') {
                    searchInput.placeholder = 'Cari dokumentasi...';
                } else {
                    searchInput.placeholder = 'Search documentation...';
                }
            }
            
            // Save language preference
            localStorage.setItem('focusbro-lang', lang);
            document.documentElement.lang = lang;
            
            // Dispatch custom event
            window.dispatchEvent(new CustomEvent('languageChanged', { 
                detail: { language: lang, updatedElements: updatedCount } 
            }));
            
            console.log(`✅ Language switched to ${lang}. Updated ${updatedCount} elements.`);
            
        } catch (error) {
            console.error('❌ Error switching language:', error);
        }
    }
    
    function loadSavedLanguage() {
        const savedLang = localStorage.getItem('focusbro-lang') || 'en';
        console.log('💾 Loading saved language:', savedLang);
        
        // Set initial active button state
        const langButtons = document.querySelectorAll('.lang-btn');
        langButtons.forEach(btn => {
            btn.classList.remove('active');
            if (btn.getAttribute('data-lang') === savedLang) {
                btn.classList.add('active');
            }
        });
        
        // Apply saved language
        switchToLanguage(savedLang);
    }
    
    // Initialize when DOM is ready
    function initialize() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
                setTimeout(() => {
                    initUniversalLanguageToggle();
                    loadSavedLanguage();
                }, 100); // Small delay to ensure other scripts load first
            });
        } else {
            setTimeout(() => {
                initUniversalLanguageToggle();
                loadSavedLanguage();
            }, 100);
        }
    }
    
    // Also listen for window load as backup
    window.addEventListener('load', function() {
        setTimeout(() => {
            console.log('🔄 Window loaded, re-initializing language toggle...');
            initUniversalLanguageToggle();
        }, 200);
    });
    
    // Initialize immediately
    initialize();
    
    // Expose functions globally for debugging
    window.FocusBroLanguage = {
        switch: switchToLanguage,
        init: initUniversalLanguageToggle,
        load: loadSavedLanguage
    };
    
    console.log('🌐 Universal Language Toggle: Script loaded');
})();
