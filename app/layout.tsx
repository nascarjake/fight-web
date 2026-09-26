import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {title:'RIFT//RIOT — Break your fate',description:'An original 3D arcade fighting game. 12 fighters. 8 arenas. Make your next round count.'};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="en"><body>{children}</body></html>}
