// FocusBro Website JavaScript

// DOM Elements
const navToggle = document.getElementById('nav-toggle');
const navMenu = document.getElementById('nav-menu');
const langButtons = document.querySelectorAll('.lang-btn');
const navbar = document.querySelector('.navbar');

// Language data
const translations = {
    en: {
        // Navigation
        'Home': 'Home',
        'Features': 'Features',
        'Documentation': 'Documentation',
        'Download': 'Download',
        
        // Hero Section
        'Boost Your Productivity with FocusBro': 'Boost Your Productivity with FocusBro',
        'A comprehensive productivity app that combines task management, focus sessions, note-taking, and PDF reading in one powerful platform.': 'A comprehensive productivity app that combines task management, focus sessions, note-taking, and PDF reading in one powerful platform.',
        'Download Now': 'Download Now',
        'View Documentation': 'View Documentation',
        
        // Features Section
        'Powerful Features': 'Powerful Features',
        'Everything you need to stay productive and focused': 'Everything you need to stay productive and focused',
        'Task Management': 'Task Management',
        'Organize your tasks with priorities, categories, and smart scheduling. Track progress with detailed analytics.': 'Organize your tasks with priorities, categories, and smart scheduling. Track progress with detailed analytics.',
        'Focus Sessions': 'Focus Sessions',
        'Pomodoro timer with customizable durations, background music, and distraction blocking features.': 'Pomodoro timer with customizable durations, background music, and distraction blocking features.',
        'Smart Notes': 'Smart Notes',
        'Take notes with tags, pinning, and advanced search. Export and share your notes easily.': 'Take notes with tags, pinning, and advanced search. Export and share your notes easily.',
        'PDF Reader': 'PDF Reader',
        'Advanced PDF viewer with annotation tools, search functionality, and document management.': 'Advanced PDF viewer with annotation tools, search functionality, and document management.',
        'Analytics': 'Analytics',
        'Track your productivity with detailed statistics, charts, and insights about your work patterns.': 'Track your productivity with detailed statistics, charts, and insights about your work patterns.',
        'Background Music': 'Background Music',
        'Built-in ambient sounds and custom music import to enhance your focus sessions.': 'Built-in ambient sounds and custom music import to enhance your focus sessions.',
        
        // Documentation Section
        'Documentation': 'Documentation',
        'Learn how to use FocusBro effectively': 'Learn how to use FocusBro effectively',
        'Getting Started': 'Getting Started',
        'Installation guide and first setup': 'Installation guide and first setup',
        'Features Guide': 'Features Guide',
        'Detailed explanation of all features': 'Detailed explanation of all features',
        'User Guide': 'User Guide',
        'Step-by-step tutorials and tips': 'Step-by-step tutorials and tips',
        'FAQ': 'FAQ',
        'Frequently asked questions': 'Frequently asked questions',
        
        // Download Section
        'Download FocusBro': 'Download FocusBro',
        'Get started with FocusBro today and boost your productivity!': 'Get started with FocusBro today and boost your productivity!',
        'Download for': 'Download for',
        'Coming Soon': 'Coming Soon',
        'Version:': 'Version:',
        'Size:': 'Size:',
        'Requirements:': 'Requirements:',
        'Scan to download': 'Scan to download',
        
        // Footer
        'Boost your productivity with the ultimate focus and task management app.': 'Boost your productivity with the ultimate focus and task management app.',
        'Quick Links': 'Quick Links',
        'Legal': 'Legal',
        'Privacy Policy': 'Privacy Policy',
        'Terms of Service': 'Terms of Service',
        'All rights reserved.': 'All rights reserved.'
    },
    id: {
        // Navigation
        'Home': 'Beranda',
        'Features': 'Fitur',
        'Documentation': 'Dokumentasi',
        'Download': 'Unduh',
        
        // Hero Section
        'Boost Your Productivity with FocusBro': 'Tingkatkan Produktivitas Anda dengan FocusBro',
        'A comprehensive productivity app that combines task management, focus sessions, note-taking, and PDF reading in one powerful platform.': 'Aplikasi produktivitas komprehensif yang menggabungkan manajemen tugas, sesi fokus, pencatatan, dan pembaca PDF dalam satu platform yang powerful.',
        'Download Now': 'Unduh Sekarang',
        'View Documentation': 'Lihat Dokumentasi',
        
        // Features Section
        'Powerful Features': 'Fitur-Fitur Powerful',
        'Everything you need to stay productive and focused': 'Semua yang Anda butuhkan untuk tetap produktif dan fokus',
        'Task Management': 'Manajemen Tugas',
        'Organize your tasks with priorities, categories, and smart scheduling. Track progress with detailed analytics.': 'Atur tugas Anda dengan prioritas, kategori, dan penjadwalan cerdas. Lacak kemajuan dengan analitik detail.',
        'Focus Sessions': 'Sesi Fokus',
        'Pomodoro timer with customizable durations, background music, and distraction blocking features.': 'Timer Pomodoro dengan durasi yang dapat disesuaikan, musik latar, dan fitur pemblokiran gangguan.',
        'Smart Notes': 'Catatan Cerdas',
        'Take notes with tags, pinning, and advanced search. Export and share your notes easily.': 'Buat catatan dengan tag, pin, dan pencarian lanjutan. Ekspor dan bagikan catatan Anda dengan mudah.',
        'PDF Reader': 'Pembaca PDF',
        'Advanced PDF viewer with annotation tools, search functionality, and document management.': 'Penampil PDF lanjutan dengan alat anotasi, fungsi pencarian, dan manajemen dokumen.',
        'Analytics': 'Analitik',
        'Track your productivity with detailed statistics, charts, and insights about your work patterns.': 'Lacak produktivitas Anda dengan statistik detail, grafik, dan wawasan tentang pola kerja Anda.',
        'Background Music': 'Musik Latar',
        'Built-in ambient sounds and custom music import to enhance your focus sessions.': 'Suara ambient bawaan dan impor musik kustom untuk meningkatkan sesi fokus Anda.',
        
        // Documentation Section
        'Documentation': 'Dokumentasi',
        'Learn how to use FocusBro effectively': 'Pelajari cara menggunakan FocusBro secara efektif',
        'Getting Started': 'Memulai',
        'Installation guide and first setup': 'Panduan instalasi dan pengaturan pertama',
        'Features Guide': 'Panduan Fitur',
        'Detailed explanation of all features': 'Penjelasan detail semua fitur',
        'User Guide': 'Panduan Pengguna',
        'Step-by-step tutorials and tips': 'Tutorial langkah demi langkah dan tips',
        'FAQ': 'FAQ',
        'Frequently asked questions': 'Pertanyaan yang sering diajukan',
        
        // Download Section
        'Download FocusBro': 'Unduh FocusBro',
        'Get started with FocusBro today and boost your productivity!': 'Mulai dengan FocusBro hari ini dan tingkatkan produktivitas Anda!',
        'Download for': 'Unduh untuk',
        'Coming Soon': 'Segera Hadir',
        'Version:': 'Versi:',
        'Size:': 'Ukuran:',
        'Requirements:': 'Persyaratan:',
        'Scan to download': 'Pindai untuk mengunduh',
        
        // Footer
        'Boost your productivity with the ultimate focus and task management app.': 'Tingkatkan produktivitas Anda dengan aplikasi fokus dan manajemen tugas terbaik.',
        'Quick Links': 'Tautan Cepat',
        'Legal': 'Legal',
        'Privacy Policy': 'Kebijakan Privasi',
        'Terms of Service': 'Syarat Layanan',
        'All rights reserved.': 'Semua hak dilindungi.'
    }
};

// Initialize the website
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    initializeLanguageSwitcher();
    initializeSmoothScrolling();
    initializeScrollEffects();
    initializeAnimations();
    
    // Set default language
    const savedLang = localStorage.getItem('focusbro-lang') || 'en';
    switchLanguage(savedLang);
});

// Navigation functionality
function initializeNavigation() {
    if (navToggle && navMenu) {
        navToggle.addEventListener('click', function() {
            navMenu.classList.toggle('active');
            navToggle.classList.toggle('active');
        });
        
        // Close menu when clicking on a link
        const navLinks = document.querySelectorAll('.nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', function() {
                navMenu.classList.remove('active');
                navToggle.classList.remove('active');
            });
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', function(e) {
            if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
                navMenu.classList.remove('active');
                navToggle.classList.remove('active');
            }
        });
    }
}

// Language switcher functionality
function initializeLanguageSwitcher() {
    langButtons.forEach(button => {
        button.addEventListener('click', function() {
            const lang = this.getAttribute('data-lang');
            switchLanguage(lang);
        });
    });
}

// Enhanced Switch language function
function switchLanguage(lang) {
    console.log('Switching language to:', lang);

    // Update active language button
    const langButtons = document.querySelectorAll('.lang-btn');
    langButtons.forEach(btn => {
        btn.classList.remove('active');
        if (btn.getAttribute('data-lang') === lang) {
            btn.classList.add('active');
        }
    });

    // Update all translatable elements using data-en/data-id attributes
    const elements = document.querySelectorAll('[data-en]');
    console.log('Found elements with data-en:', elements.length);

    elements.forEach(element => {
        const enText = element.getAttribute('data-en');
        const idText = element.getAttribute('data-id');

        if (lang === 'en' && enText) {
            element.textContent = enText;
        } else if (lang === 'id' && idText) {
            element.textContent = idText;
        }
    });

    // Update elements using translation keys
    const keyElements = document.querySelectorAll('[data-translate]');
    keyElements.forEach(element => {
        const key = element.getAttribute('data-translate');
        if (translations[lang] && translations[lang][key]) {
            element.textContent = translations[lang][key];
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

    // Update search placeholder
    const searchInput = document.getElementById('site-search');
    if (searchInput) {
        if (lang === 'id') {
            searchInput.placeholder = 'Cari dokumentasi...';
        } else {
            searchInput.placeholder = 'Search documentation...';
        }
    }

    // Update search data for current language
    if (typeof updateSearchDataLanguage === 'function') {
        updateSearchDataLanguage(lang);
    }

    // Save language preference
    localStorage.setItem('focusbro-lang', lang);

    // Update document language
    document.documentElement.lang = lang;

    // Trigger custom event for other components
    window.dispatchEvent(new CustomEvent('languageChanged', { detail: { language: lang } }));

    console.log('Language switched to:', lang);
}

// Update search data based on language
function updateSearchDataLanguage(lang) {
    if (typeof searchData !== 'undefined') {
        searchData.forEach(item => {
            if (lang === 'id') {
                // Update to Indonesian
                switch(item.title) {
                    case 'Getting Started':
                        item.title = 'Memulai';
                        item.description = 'Panduan instalasi dan pengaturan awal';
                        break;
                    case 'Task Management':
                        item.title = 'Manajemen Tugas';
                        item.description = 'Buat, atur dan lacak tugas Anda';
                        break;
                    case 'Focus Sessions':
                        item.title = 'Sesi Fokus';
                        item.description = 'Timer Pomodoro dan sesi produktivitas';
                        break;
                    case 'Smart Notes':
                        item.title = 'Catatan Pintar';
                        item.description = 'Buat dan atur catatan dengan tag';
                        break;
                    case 'PDF Reader':
                        item.title = 'Pembaca PDF';
                        item.description = 'Baca dan beri anotasi dokumen PDF';
                        break;
                    case 'Background Music':
                        item.title = 'Musik Latar';
                        item.description = 'Suara ambient dan musik untuk fokus';
                        break;
                    case 'Analytics Dashboard':
                        item.title = 'Dashboard Analitik';
                        item.description = 'Lacak produktivitas dan kemajuan Anda';
                        break;
                    case 'Settings & Customization':
                        item.title = 'Pengaturan & Kustomisasi';
                        item.description = 'Sesuaikan preferensi dan perilaku aplikasi';
                        break;
                    case 'FAQ':
                        item.title = 'Tanya Jawab';
                        item.description = 'Pertanyaan yang sering diajukan';
                        break;
                    case 'Troubleshooting':
                        item.title = 'Pemecahan Masalah';
                        item.description = 'Solusi untuk masalah umum';
                        break;
                    case 'Privacy Policy':
                        item.title = 'Kebijakan Privasi';
                        item.description = 'Bagaimana kami melindungi data Anda';
                        break;
                    case 'Terms of Service':
                        item.title = 'Syarat Layanan';
                        item.description = 'Syarat dan ketentuan penggunaan FocusBro';
                        break;
                    case 'Changelog':
                        item.title = 'Riwayat Perubahan';
                        item.description = 'Riwayat versi dan catatan rilis';
                        break;
                    case 'Screenshots Gallery':
                        item.title = 'Galeri Screenshot';
                        item.description = 'Tampilan visual fitur aplikasi';
                        break;
                    case 'API Documentation':
                        item.title = 'Dokumentasi API';
                        item.description = 'Sumber daya pengembang dan format data';
                        break;
                    case 'Send Feedback':
                        item.title = 'Kirim Masukan';
                        item.description = 'Bagikan saran dan laporkan masalah';
                        break;
                }
            } else {
                // Reset to English
                switch(item.title) {
                    case 'Memulai':
                        item.title = 'Getting Started';
                        item.description = 'Installation guide and initial setup';
                        break;
                    case 'Manajemen Tugas':
                        item.title = 'Task Management';
                        item.description = 'Create, organize and track your tasks';
                        break;
                    case 'Sesi Fokus':
                        item.title = 'Focus Sessions';
                        item.description = 'Pomodoro timer and productivity sessions';
                        break;
                    case 'Catatan Pintar':
                        item.title = 'Smart Notes';
                        item.description = 'Take and organize notes with tags';
                        break;
                    case 'Pembaca PDF':
                        item.title = 'PDF Reader';
                        item.description = 'Read and annotate PDF documents';
                        break;
                    case 'Musik Latar':
                        item.title = 'Background Music';
                        item.description = 'Ambient sounds and music for focus';
                        break;
                    case 'Dashboard Analitik':
                        item.title = 'Analytics Dashboard';
                        item.description = 'Track your productivity and progress';
                        break;
                    case 'Pengaturan & Kustomisasi':
                        item.title = 'Settings & Customization';
                        item.description = 'Customize app preferences and behavior';
                        break;
                    case 'Tanya Jawab':
                        item.title = 'FAQ';
                        item.description = 'Frequently asked questions and answers';
                        break;
                    case 'Pemecahan Masalah':
                        item.title = 'Troubleshooting';
                        item.description = 'Solutions for common problems and issues';
                        break;
                    case 'Kebijakan Privasi':
                        item.title = 'Privacy Policy';
                        item.description = 'How we protect your data and privacy';
                        break;
                    case 'Syarat Layanan':
                        item.title = 'Terms of Service';
                        item.description = 'Legal terms and conditions for using FocusBro';
                        break;
                    case 'Riwayat Perubahan':
                        item.title = 'Changelog';
                        item.description = 'Version history and release notes';
                        break;
                    case 'Galeri Screenshot':
                        item.title = 'Screenshots Gallery';
                        item.description = 'Visual showcase of app features';
                        break;
                    case 'Dokumentasi API':
                        item.title = 'API Documentation';
                        item.description = 'Developer resources and data formats';
                        break;
                    case 'Kirim Masukan':
                        item.title = 'Send Feedback';
                        item.description = 'Share suggestions and report issues';
                        break;
                }
            }
        });
    }
}

// Smooth scrolling for navigation links
function initializeSmoothScrolling() {
    const links = document.querySelectorAll('a[href^="#"]');
    links.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                const offsetTop = targetElement.offsetTop - 70; // Account for fixed navbar
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// Scroll effects
function initializeScrollEffects() {
    window.addEventListener('scroll', function() {
        // Navbar background on scroll
        if (navbar) {
            if (window.scrollY > 50) {
                navbar.style.background = 'rgba(255, 255, 255, 0.98)';
                navbar.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.1)';
            } else {
                navbar.style.background = 'rgba(255, 255, 255, 0.95)';
                navbar.style.boxShadow = 'none';
            }
        }
        
        // Animate elements on scroll
        animateOnScroll();
    });
}

// Animation on scroll
function animateOnScroll() {
    const elements = document.querySelectorAll('.feature-card, .doc-card');
    elements.forEach(element => {
        const elementTop = element.getBoundingClientRect().top;
        const elementVisible = 150;
        
        if (elementTop < window.innerHeight - elementVisible) {
            element.style.opacity = '1';
            element.style.transform = 'translateY(0)';
        }
    });
}

// Initialize animations
function initializeAnimations() {
    // Set initial state for animated elements
    const animatedElements = document.querySelectorAll('.feature-card, .doc-card');
    animatedElements.forEach(element => {
        element.style.opacity = '0';
        element.style.transform = 'translateY(30px)';
        element.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
    });
    
    // Trigger initial animation check
    setTimeout(animateOnScroll, 100);
}

// Utility functions
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Add debounced scroll listener for better performance
window.addEventListener('scroll', debounce(function() {
    animateOnScroll();
}, 10));

// Handle download button clicks
document.addEventListener('click', function(e) {
    if (e.target.closest('.download-btn.android')) {
        // Track download analytics if needed
        console.log('Android download initiated');
    }
});

// Error handling for missing images
document.addEventListener('DOMContentLoaded', function() {
    const images = document.querySelectorAll('img');
    images.forEach(img => {
        img.addEventListener('error', function() {
            this.style.display = 'none';
            console.warn('Image failed to load:', this.src);
        });
    });
});

// Enhanced Search functionality
const searchData = [
    {
        title: 'Getting Started',
        description: 'Installation guide and initial setup',
        url: 'docs/getting-started.html',
        category: 'Guide',
        icon: 'fas fa-play',
        keywords: ['install', 'download', 'setup', 'start', 'begin', 'apk', 'android']
    },
    {
        title: 'Task Management',
        description: 'Create, organize and track your tasks',
        url: 'docs/user-guide.html',
        category: 'Feature',
        icon: 'fas fa-tasks',
        keywords: ['task', 'todo', 'manage', 'organize', 'priority', 'category', 'deadline']
    },
    {
        title: 'Focus Sessions',
        description: 'Pomodoro timer and productivity sessions',
        url: 'docs/user-guide.html',
        category: 'Feature',
        icon: 'fas fa-bullseye',
        keywords: ['focus', 'timer', 'pomodoro', 'session', 'productivity', 'concentration']
    },
    {
        title: 'Smart Notes',
        description: 'Take and organize notes with tags',
        url: 'docs/user-guide.html',
        category: 'Feature',
        icon: 'fas fa-sticky-note',
        keywords: ['notes', 'note', 'write', 'tag', 'organize', 'text', 'memo']
    },
    {
        title: 'PDF Reader',
        description: 'Read and annotate PDF documents',
        url: 'docs/features.html',
        category: 'Feature',
        icon: 'fas fa-file-pdf',
        keywords: ['pdf', 'reader', 'document', 'annotate', 'highlight', 'bookmark']
    },
    {
        title: 'Background Music',
        description: 'Ambient sounds and music for focus',
        url: 'docs/features.html',
        category: 'Feature',
        icon: 'fas fa-music',
        keywords: ['music', 'sound', 'ambient', 'audio', 'playlist', 'focus']
    },
    {
        title: 'Analytics Dashboard',
        description: 'Track your productivity and progress',
        url: 'analytics.html',
        category: 'Feature',
        icon: 'fas fa-chart-bar',
        keywords: ['analytics', 'statistics', 'progress', 'tracking', 'productivity', 'insights']
    },
    {
        title: 'Settings & Customization',
        description: 'Customize app preferences and behavior',
        url: 'docs/features.html',
        category: 'Feature',
        icon: 'fas fa-cog',
        keywords: ['settings', 'preferences', 'customize', 'configuration', 'options']
    },
    {
        title: 'FAQ',
        description: 'Frequently asked questions and answers',
        url: 'docs/faq.html',
        category: 'Help',
        icon: 'fas fa-question-circle',
        keywords: ['faq', 'help', 'question', 'answer', 'support', 'common']
    },
    {
        title: 'Troubleshooting',
        description: 'Solutions for common problems and issues',
        url: 'docs/troubleshooting.html',
        category: 'Help',
        icon: 'fas fa-tools',
        keywords: ['troubleshoot', 'problem', 'issue', 'error', 'bug', 'fix', 'solution']
    },
    {
        title: 'Privacy Policy',
        description: 'How we protect your data and privacy',
        url: 'privacy.html',
        category: 'Legal',
        icon: 'fas fa-shield-alt',
        keywords: ['privacy', 'data', 'protection', 'security', 'policy']
    },
    {
        title: 'Terms of Service',
        description: 'Legal terms and conditions for using FocusBro',
        url: 'terms.html',
        category: 'Legal',
        icon: 'fas fa-file-contract',
        keywords: ['terms', 'service', 'legal', 'conditions', 'agreement']
    },
    {
        title: 'Changelog',
        description: 'Version history and release notes',
        url: 'changelog.html',
        category: 'Info',
        icon: 'fas fa-history',
        keywords: ['changelog', 'version', 'update', 'release', 'history', 'new']
    },
    {
        title: 'Screenshots Gallery',
        description: 'Visual showcase of app features',
        url: 'gallery.html',
        category: 'Info',
        icon: 'fas fa-images',
        keywords: ['screenshot', 'gallery', 'image', 'visual', 'preview', 'demo']
    },
    {
        title: 'API Documentation',
        description: 'Developer resources and data formats',
        url: 'docs/api.html',
        category: 'Developer',
        icon: 'fas fa-code',
        keywords: ['api', 'developer', 'integration', 'data', 'format', 'export', 'import']
    },
    {
        title: 'Send Feedback',
        description: 'Share suggestions and report issues',
        url: 'feedback.html',
        category: 'Support',
        icon: 'fas fa-comment',
        keywords: ['feedback', 'suggestion', 'report', 'bug', 'contact', 'support']
    }
];

let searchTimeout;
let currentHighlight = -1;

// Initialize search functionality
function initializeSearch() {
    const searchInput = document.getElementById('site-search');
    const searchClear = document.getElementById('searchClear');
    const searchSuggestions = document.getElementById('searchSuggestions');
    const searchContainer = document.getElementById('searchContainer');

    if (!searchInput) {
        console.log('Search input not found');
        return;
    }

    console.log('Search initialized');

    // Input event for real-time search
    searchInput.addEventListener('input', function(e) {
        const query = e.target.value.trim();
        console.log('Search query:', query);

        // Show/hide clear button
        if (query) {
            searchClear.style.display = 'flex';
        } else {
            searchClear.style.display = 'none';
            hideSuggestions();
            return;
        }

        // Debounce search
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            performSearch(query);
        }, 150);
    });

    // Clear button
    if (searchClear) {
        searchClear.addEventListener('click', function() {
            searchInput.value = '';
            searchClear.style.display = 'none';
            hideSuggestions();
            searchInput.focus();
        });
    }

    // Keyboard navigation
    searchInput.addEventListener('keydown', function(e) {
        const suggestions = document.querySelectorAll('.search-suggestion');

        if (e.key === 'ArrowDown') {
            e.preventDefault();
            currentHighlight = Math.min(currentHighlight + 1, suggestions.length - 1);
            updateHighlight(suggestions);
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            currentHighlight = Math.max(currentHighlight - 1, -1);
            updateHighlight(suggestions);
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (currentHighlight >= 0 && suggestions[currentHighlight]) {
                suggestions[currentHighlight].click();
            } else if (searchInput.value.trim()) {
                performDirectSearch(searchInput.value.trim());
            }
        } else if (e.key === 'Escape') {
            hideSuggestions();
        }
    });

    // Click outside to close
    document.addEventListener('click', function(e) {
        if (searchContainer && !searchContainer.contains(e.target)) {
            hideSuggestions();
        }
    });
}

function performSearch(query) {
    console.log('Performing search for:', query);

    if (!query || query.length < 1) {
        hideSuggestions();
        return;
    }

    const results = searchInData(query);
    console.log('Search results:', results);
    displaySuggestions(results, query);
}

function searchInData(query) {
    const lowerQuery = query.toLowerCase();
    const results = [];

    searchData.forEach(item => {
        let score = 0;

        // Title exact match (highest score)
        if (item.title.toLowerCase().includes(lowerQuery)) {
            score += 100;
        }

        // Keywords match
        const keywordMatches = item.keywords.filter(keyword =>
            keyword.toLowerCase().includes(lowerQuery) ||
            lowerQuery.includes(keyword.toLowerCase())
        );
        score += keywordMatches.length * 50;

        // Description match
        if (item.description.toLowerCase().includes(lowerQuery)) {
            score += 25;
        }

        // Category match
        if (item.category.toLowerCase().includes(lowerQuery)) {
            score += 10;
        }

        if (score > 0) {
            results.push({ ...item, score });
        }
    });

    // Sort by score (highest first)
    return results.sort((a, b) => b.score - a.score).slice(0, 6);
}

function displaySuggestions(results, query) {
    const searchSuggestions = document.getElementById('searchSuggestions');
    if (!searchSuggestions) {
        console.log('Search suggestions container not found');
        return;
    }

    currentHighlight = -1;

    if (results.length === 0) {
        searchSuggestions.innerHTML = `
            <div class="search-no-results">
                <i class="fas fa-search"></i>
                <div>No results found for "${query}"</div>
                <div>Try different keywords or check our FAQ</div>
            </div>
        `;
    } else {
        searchSuggestions.innerHTML = results.map(item => `
            <div class="search-suggestion" data-url="${item.url}">
                <div class="search-suggestion-icon">
                    <i class="${item.icon}"></i>
                </div>
                <div class="search-suggestion-content">
                    <div class="search-suggestion-title">${highlightText(item.title, query)}</div>
                    <div class="search-suggestion-description">${item.description}</div>
                </div>
                <div class="search-suggestion-category">${item.category}</div>
            </div>
        `).join('');

        // Add click handlers
        document.querySelectorAll('.search-suggestion').forEach(suggestion => {
            suggestion.addEventListener('click', function() {
                const url = this.getAttribute('data-url');
                console.log('Navigating to:', url);
                window.location.href = url;
            });
        });
    }

    searchSuggestions.classList.add('show');
}

function highlightText(text, query) {
    if (!query) return text;

    const regex = new RegExp(`(${query})`, 'gi');
    return text.replace(regex, '<strong style="color: var(--primary-color);">$1</strong>');
}

function updateHighlight(suggestions) {
    suggestions.forEach((suggestion, index) => {
        if (index === currentHighlight) {
            suggestion.classList.add('highlighted');
        } else {
            suggestion.classList.remove('highlighted');
        }
    });
}

function hideSuggestions() {
    const searchSuggestions = document.getElementById('searchSuggestions');
    if (searchSuggestions) {
        searchSuggestions.classList.remove('show');
    }
    currentHighlight = -1;
}

function performDirectSearch(query) {
    // Fallback for direct search when no suggestions are selected
    const results = searchInData(query);
    if (results.length > 0) {
        window.location.href = results[0].url;
    } else {
        window.location.href = 'docs/faq.html';
    }
}

// PWA Installation
let deferredPrompt;
let installButton;

// Listen for beforeinstallprompt event
window.addEventListener('beforeinstallprompt', (e) => {
    // Prevent Chrome 67 and earlier from automatically showing the prompt
    e.preventDefault();
    // Stash the event so it can be triggered later
    deferredPrompt = e;
    // Show install button
    showInstallButton();
});

// Show PWA install button
function showInstallButton() {
    // Create install button if it doesn't exist
    if (!installButton) {
        installButton = document.createElement('button');
        installButton.innerHTML = '<i class="fas fa-download"></i> Install App';
        installButton.className = 'btn btn-secondary pwa-install-btn';
        installButton.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 1000;
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 12px 20px;
            background: var(--primary-color);
            color: white;
            border: none;
            border-radius: 12px;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            transition: all 0.3s ease;
        `;

        installButton.addEventListener('click', installPWA);
        document.body.appendChild(installButton);

        // Animate in
        setTimeout(() => {
            installButton.style.transform = 'translateY(0)';
            installButton.style.opacity = '1';
        }, 100);
    }
}

// Install PWA
async function installPWA() {
    if (deferredPrompt) {
        // Show the install prompt
        deferredPrompt.prompt();

        // Wait for the user to respond to the prompt
        const { outcome } = await deferredPrompt.userChoice;

        if (outcome === 'accepted') {
            console.log('User accepted the install prompt');
            hideInstallButton();
        } else {
            console.log('User dismissed the install prompt');
        }

        // Clear the deferredPrompt
        deferredPrompt = null;
    }
}

// Hide install button
function hideInstallButton() {
    if (installButton) {
        installButton.style.transform = 'translateY(100px)';
        installButton.style.opacity = '0';
        setTimeout(() => {
            if (installButton && installButton.parentNode) {
                installButton.parentNode.removeChild(installButton);
            }
        }, 300);
    }
}

// Listen for app installed event
window.addEventListener('appinstalled', (evt) => {
    console.log('PWA was installed');
    hideInstallButton();

    // Show success message
    showNotification('FocusBro Docs installed successfully!', 'success');
});

// Register Service Worker
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then((registration) => {
                console.log('SW registered: ', registration);

                // Check for updates
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    newWorker.addEventListener('statechange', () => {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            // New content is available
                            showUpdateNotification();
                        }
                    });
                });
            })
            .catch((registrationError) => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}

// Show update notification
function showUpdateNotification() {
    const notification = document.createElement('div');
    notification.innerHTML = `
        <div style="
            position: fixed;
            top: 20px;
            right: 20px;
            background: white;
            padding: 16px 20px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            border-left: 4px solid var(--primary-color);
            z-index: 1001;
            max-width: 300px;
        ">
            <div style="font-weight: 600; margin-bottom: 8px; color: var(--text-primary);">
                Update Available
            </div>
            <div style="font-size: 14px; color: var(--text-secondary); margin-bottom: 12px;">
                A new version of FocusBro Docs is available.
            </div>
            <button onclick="updateApp()" style="
                background: var(--primary-color);
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 6px;
                cursor: pointer;
                font-weight: 500;
                margin-right: 8px;
            ">Update</button>
            <button onclick="this.parentElement.parentElement.remove()" style="
                background: transparent;
                color: var(--text-secondary);
                border: 1px solid var(--border-color);
                padding: 8px 16px;
                border-radius: 6px;
                cursor: pointer;
            ">Later</button>
        </div>
    `;
    document.body.appendChild(notification);
}

// Update app
function updateApp() {
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistration().then((registration) => {
            if (registration && registration.waiting) {
                registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                window.location.reload();
            }
        });
    }
}

// Show notification helper
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    const colors = {
        success: { bg: '#d1fae5', border: '#34d399', text: '#065f46' },
        error: { bg: '#fee2e2', border: '#f87171', text: '#991b1b' },
        info: { bg: '#f0f9ff', border: '#0ea5e9', text: '#0c4a6e' }
    };

    const color = colors[type] || colors.info;

    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${color.bg};
        color: ${color.text};
        border: 1px solid ${color.border};
        padding: 12px 20px;
        border-radius: 8px;
        z-index: 1002;
        font-weight: 500;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        animation: slideIn 0.3s ease;
    `;

    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
        notification.remove();
    }, 4000);
}

// Simple working search implementation
function setupSimpleSearch() {
    const searchInput = document.getElementById('site-search');
    const searchClear = document.getElementById('searchClear');
    const searchContainer = document.getElementById('searchContainer');

    if (!searchInput) {
        console.log('Search input not found');
        return;
    }

    console.log('Setting up simple search...');

    // Create suggestions container if it doesn't exist
    let searchSuggestions = document.getElementById('searchSuggestions');
    if (!searchSuggestions) {
        searchSuggestions = document.createElement('div');
        searchSuggestions.id = 'searchSuggestions';
        searchSuggestions.className = 'search-suggestions';
        searchContainer.appendChild(searchSuggestions);
    }

    // Simple search data
    const simpleSearchData = [
        { title: 'Getting Started', url: 'docs/getting-started.html', icon: 'fas fa-play', category: 'Guide' },
        { title: 'Task Management', url: 'docs/user-guide.html', icon: 'fas fa-tasks', category: 'Feature' },
        { title: 'Focus Sessions', url: 'docs/user-guide.html', icon: 'fas fa-bullseye', category: 'Feature' },
        { title: 'PDF Reader', url: 'docs/features.html', icon: 'fas fa-file-pdf', category: 'Feature' },
        { title: 'Background Music', url: 'docs/features.html', icon: 'fas fa-music', category: 'Feature' },
        { title: 'FAQ', url: 'docs/faq.html', icon: 'fas fa-question-circle', category: 'Help' },
        { title: 'Troubleshooting', url: 'docs/troubleshooting.html', icon: 'fas fa-tools', category: 'Help' },
        { title: 'Privacy Policy', url: 'privacy.html', icon: 'fas fa-shield-alt', category: 'Legal' }
    ];

    let searchTimeout;

    // Input event
    searchInput.addEventListener('input', function(e) {
        const query = e.target.value.trim().toLowerCase();
        console.log('Search query:', query);

        // Show/hide clear button
        if (query) {
            searchClear.style.display = 'flex';
        } else {
            searchClear.style.display = 'none';
            searchSuggestions.classList.remove('show');
            return;
        }

        // Debounce search
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            showSimpleResults(query, simpleSearchData, searchSuggestions);
        }, 150);
    });

    // Clear button
    if (searchClear) {
        searchClear.addEventListener('click', function() {
            searchInput.value = '';
            searchClear.style.display = 'none';
            searchSuggestions.classList.remove('show');
            searchInput.focus();
        });
    }

    // Click outside to close
    document.addEventListener('click', function(e) {
        if (!searchContainer.contains(e.target)) {
            searchSuggestions.classList.remove('show');
        }
    });
}

function showSimpleResults(query, data, container) {
    const results = data.filter(item =>
        item.title.toLowerCase().includes(query) ||
        item.category.toLowerCase().includes(query)
    );

    if (results.length === 0) {
        container.innerHTML = `
            <div class="search-no-results">
                <i class="fas fa-search"></i>
                <div>No results found for "${query}"</div>
                <div>Try different keywords</div>
            </div>
        `;
    } else {
        container.innerHTML = results.map(item => `
            <div class="search-suggestion" onclick="window.location.href='${item.url}'">
                <div class="search-suggestion-icon">
                    <i class="${item.icon}"></i>
                </div>
                <div class="search-suggestion-content">
                    <div class="search-suggestion-title">${item.title}</div>
                    <div class="search-suggestion-description">Navigate to ${item.title}</div>
                </div>
                <div class="search-suggestion-category">${item.category}</div>
            </div>
        `).join('');
    }

    container.classList.add('show');
}

// Initialize language switcher
function initializeLanguageSwitcher() {
    console.log('Initializing language switcher...');

    const langButtons = document.querySelectorAll('.lang-btn');
    console.log('Found language buttons:', langButtons.length);

    langButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            const lang = this.getAttribute('data-lang');
            console.log('Language button clicked:', lang);
            switchLanguage(lang);
        });
    });
}

// Initialize all features when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, initializing features...');

    // Initialize language switcher
    initializeLanguageSwitcher();

    // Load saved language preference
    const savedLang = localStorage.getItem('focusbro-lang') || 'en';
    switchLanguage(savedLang);

    // Setup simple search
    setupSimpleSearch();

    // Also try the advanced search
    if (typeof initializeSearch === 'function') {
        initializeSearch();
    }

    // Debug search elements
    const searchInput = document.getElementById('site-search');
    const searchSuggestions = document.getElementById('searchSuggestions');
    const searchContainer = document.getElementById('searchContainer');

    console.log('Search elements found:', {
        input: !!searchInput,
        suggestions: !!searchSuggestions,
        container: !!searchContainer
    });

    console.log('Language switcher initialized with language:', savedLang);
});
