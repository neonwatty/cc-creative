/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/views/**/*.html.erb",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.css",
    "./app/javascript/**/*.js",
    "./app/components/**/*.rb",
    "./app/components/**/*.html.erb"
  ],
  darkMode: 'class',
  theme: {
    extend: {
      // Creative-focused color palette
      colors: {
        'creative-primary': {
          50: '#eff6ff',
          100: '#dbeafe', 
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6', // Main creative-primary
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
          950: '#172554'
        },
        'creative-secondary': {
          50: '#ecfdf5',
          100: '#d1fae5',
          200: '#a7f3d0',
          300: '#6ee7b7',
          400: '#34d399',
          500: '#10b981', // Main creative-secondary
          600: '#059669',
          700: '#047857',
          800: '#065f46',
          900: '#064e3b',
          950: '#022c22'
        },
        // Extended neutral palette for creative work
        'creative-neutral': {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
          950: '#020617'
        },
        // Accent colors for creative elements
        'creative-accent': {
          amber: '#f59e0b',
          orange: '#ea580c',
          rose: '#e11d48',
          purple: '#9333ea',
          indigo: '#6366f1',
          teal: '#0d9488'
        }
      },
      
      // Custom spacing scale optimized for document layouts
      spacing: {
        '18': '4.5rem',
        '72': '18rem',
        '84': '21rem',
        '96': '24rem',
        '128': '32rem',
        '144': '36rem'
      },
      
      // Typography scale optimized for content creation
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],
        'sm': ['0.875rem', { lineHeight: '1.25rem' }],
        'base': ['1rem', { lineHeight: '1.5rem' }],
        'lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'xl': ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
        '5xl': ['3rem', { lineHeight: '1' }],
        '6xl': ['3.75rem', { lineHeight: '1' }],
        '7xl': ['4.5rem', { lineHeight: '1' }],
        '8xl': ['6rem', { lineHeight: '1' }],
        '9xl': ['8rem', { lineHeight: '1' }],
        // Custom content sizes
        'content-sm': ['0.875rem', { lineHeight: '1.5rem' }],
        'content-base': ['1rem', { lineHeight: '1.625rem' }],
        'content-lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'heading-sm': ['1.25rem', { lineHeight: '1.5rem', fontWeight: '600' }],
        'heading-md': ['1.5rem', { lineHeight: '1.75rem', fontWeight: '600' }],
        'heading-lg': ['2rem', { lineHeight: '2.25rem', fontWeight: '700' }],
        'heading-xl': ['2.5rem', { lineHeight: '2.75rem', fontWeight: '700' }]
      },
      
      // Custom font families for creative work
      fontFamily: {
        'sans': ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        'serif': ['Merriweather', 'ui-serif', 'Georgia', 'serif'],
        'mono': ['JetBrains Mono', 'ui-monospace', 'monospace'],
        'display': ['Cal Sans', 'ui-sans-serif', 'system-ui', 'sans-serif']
      },
      
      // Enhanced border radius for modern design
      borderRadius: {
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
        '4xl': '2rem'
      },
      
      // Custom shadows for depth and elevation
      boxShadow: {
        'creative-sm': '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
        'creative': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'creative-md': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'creative-lg': '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
        'creative-xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        'creative-2xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        'creative-inner': 'inset 0 2px 4px 0 rgba(0, 0, 0, 0.06)',
        // Dark mode shadows
        'creative-dark-sm': '0 1px 2px 0 rgba(0, 0, 0, 0.3)',
        'creative-dark': '0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -1px rgba(0, 0, 0, 0.2)',
        'creative-dark-md': '0 10px 15px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -2px rgba(0, 0, 0, 0.2)',
        'creative-dark-lg': '0 20px 25px -5px rgba(0, 0, 0, 0.4), 0 10px 10px -5px rgba(0, 0, 0, 0.2)',
        'creative-dark-xl': '0 25px 50px -12px rgba(0, 0, 0, 0.5)'
      },
      
      // Animation and transition utilities
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out forwards',
        'fade-out': 'fadeOut 0.3s ease-out forwards',
        'slide-in-right': 'slideInRight 0.3s ease-out forwards',
        'slide-in-left': 'slideInLeft 0.3s ease-out forwards',
        'slide-up': 'slideUp 0.3s ease-out forwards',
        'slide-down': 'slideDown 0.3s ease-out forwards',
        'scale-in': 'scaleIn 0.2s ease-out forwards',
        'scale-out': 'scaleOut 0.2s ease-out forwards',
        'bounce-gentle': 'bounceGentle 0.6s ease-out forwards',
        'pulse-gentle': 'pulseGentle 2s infinite',
        'wiggle': 'wiggle 0.8s ease-in-out infinite'
      },
      
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(-10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        fadeOut: {
          '0%': { opacity: '1', transform: 'translateY(0)' },
          '100%': { opacity: '0', transform: 'translateY(-10px)' }
        },
        slideInRight: {
          '0%': { opacity: '0', transform: 'translateX(20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' }
        },
        slideInLeft: {
          '0%': { opacity: '0', transform: 'translateX(-20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' }
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.9)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        },
        scaleOut: {
          '0%': { opacity: '1', transform: 'scale(1)' },
          '100%': { opacity: '0', transform: 'scale(0.9)' }
        },
        bounceGentle: {
          '0%': { transform: 'translateY(-5px)' },
          '50%': { transform: 'translateY(0)' },
          '100%': { transform: 'translateY(-5px)' }
        },
        pulseGentle: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' }
        },
        wiggle: {
          '0%, 100%': { transform: 'rotate(-1deg)' },
          '50%': { transform: 'rotate(1deg)' }
        }
      },
      
      // Custom transition timing
      transitionTimingFunction: {
        'creative': 'cubic-bezier(0.4, 0, 0.2, 1)',
        'creative-in': 'cubic-bezier(0.4, 0, 1, 1)',
        'creative-out': 'cubic-bezier(0, 0, 0.2, 1)',
        'creative-in-out': 'cubic-bezier(0.4, 0, 0.2, 1)'
      },
      
      // Custom transition durations
      transitionDuration: {
        '400': '400ms',
        '600': '600ms',
        '800': '800ms',
        '1200': '1200ms'
      },

      // Container sizes for different layouts
      maxWidth: {
        'prose-sm': '45ch',
        'prose': '65ch',
        'prose-lg': '75ch',
        'prose-xl': '85ch'
      },

      // Custom z-index scale
      zIndex: {
        '60': '60',
        '70': '70',
        '80': '80',
        '90': '90',
        '100': '100'
      }
    }
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    // Custom plugin for component utilities
    function({ addUtilities, addComponents, theme }) {
      // Component-based button classes
      addComponents({
        '.btn': {
          padding: theme('spacing.2') + ' ' + theme('spacing.4'),
          borderRadius: theme('borderRadius.md'),
          fontWeight: theme('fontWeight.medium'),
          fontSize: theme('fontSize.sm'),
          lineHeight: theme('lineHeight.5'),
          transition: 'all 150ms cubic-bezier(0.4, 0, 0.2, 1)',
          cursor: 'pointer',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          border: '1px solid transparent',
          '&:focus': {
            outline: '2px solid transparent',
            outlineOffset: '2px',
            boxShadow: theme('boxShadow.creative')
          }
        },
        '.btn-primary': {
          backgroundColor: theme('colors.creative-primary.500'),
          color: theme('colors.white'),
          '&:hover': {
            backgroundColor: theme('colors.creative-primary.600')
          },
          '&:focus': {
            boxShadow: '0 0 0 3px ' + theme('colors.creative-primary.200')
          }
        },
        '.btn-secondary': {
          backgroundColor: theme('colors.creative-secondary.500'),
          color: theme('colors.white'),
          '&:hover': {
            backgroundColor: theme('colors.creative-secondary.600')
          },
          '&:focus': {
            boxShadow: '0 0 0 3px ' + theme('colors.creative-secondary.200')
          }
        },
        '.btn-outline': {
          backgroundColor: 'transparent',
          borderColor: theme('colors.creative-neutral.300'),
          color: theme('colors.creative-neutral.700'),
          '&:hover': {
            backgroundColor: theme('colors.creative-neutral.50'),
            borderColor: theme('colors.creative-neutral.400')
          }
        },
        '.btn-ghost': {
          backgroundColor: 'transparent',
          color: theme('colors.creative-neutral.600'),
          '&:hover': {
            backgroundColor: theme('colors.creative-neutral.100'),
            color: theme('colors.creative-neutral.800')
          }
        }
      });

      // Card components
      addComponents({
        '.card': {
          backgroundColor: theme('colors.white'),
          borderRadius: theme('borderRadius.lg'),
          boxShadow: theme('boxShadow.creative'),
          padding: theme('spacing.6'),
          border: '1px solid ' + theme('colors.creative-neutral.200')
        },
        '.card-compact': {
          padding: theme('spacing.4')
        },
        '.card-spacious': {
          padding: theme('spacing.8')
        }
      });

      // Input components
      addComponents({
        '.input': {
          appearance: 'none',
          backgroundColor: theme('colors.white'),
          borderColor: theme('colors.creative-neutral.300'),
          borderWidth: '1px',
          borderRadius: theme('borderRadius.md'),
          padding: theme('spacing.2') + ' ' + theme('spacing.3'),
          fontSize: theme('fontSize.sm'),
          lineHeight: theme('lineHeight.5'),
          '&:focus': {
            outline: '2px solid transparent',
            outlineOffset: '2px',
            borderColor: theme('colors.creative-primary.500'),
            boxShadow: '0 0 0 3px ' + theme('colors.creative-primary.200')
          }
        }
      });

      // Dark mode variants
      addUtilities({
        '.dark .card': {
          backgroundColor: theme('colors.creative-neutral.800'),
          borderColor: theme('colors.creative-neutral.700'),
          boxShadow: theme('boxShadow.creative-dark')
        },
        '.dark .input': {
          backgroundColor: theme('colors.creative-neutral.800'),
          borderColor: theme('colors.creative-neutral.600'),
          color: theme('colors.creative-neutral.100'),
          '&:focus': {
            borderColor: theme('colors.creative-primary.400'),
            boxShadow: '0 0 0 3px ' + theme('colors.creative-primary.800')
          }
        },
        '.dark .btn-outline': {
          borderColor: theme('colors.creative-neutral.600'),
          color: theme('colors.creative-neutral.300'),
          '&:hover': {
            backgroundColor: theme('colors.creative-neutral.700'),
            borderColor: theme('colors.creative-neutral.500')
          }
        },
        '.dark .btn-ghost': {
          color: theme('colors.creative-neutral.400'),
          '&:hover': {
            backgroundColor: theme('colors.creative-neutral.700'),
            color: theme('colors.creative-neutral.200')
          }
        }
      });
    }
  ]
}