Name: harbour-mullvad

Summary: Minimal Mullvad WireGuard client for Sailfish OS
Version: 0.1
Release: 1
Group: Qt/Qt
License: BSD
URL: https://github.com/MrCyjaneK/spikes_sfos
Source0: %{name}-%{version}.tar.bz2
Requires: sailfishsilica-qt5 >= 0.10.9
BuildRequires: pkgconfig(sailfishapp) >= 1.0.2
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Gui)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: desktop-file-utils
BuildRequires: pkgconfig(dbus-1)

%description
Log in with a Mullvad account number, list and remove devices, register a
WireGuard key, and connect through ConnMan's WireGuard VPN the same way
Settings does. The 5-device account limit is handled by kicking a
device before connecting.

%prep
%autosetup -n %{name}-%{version}

%build
%qmake5
%make_build
gcc -O2 -s -o harbour-mullvad-vpn src/tunnel-helper.c $(pkg-config --cflags --libs dbus-1)

%install
%qmake5_install
install -D -m 2755 harbour-mullvad-vpn %{buildroot}%{_libexecdir}/harbour-mullvad-vpn
desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%files
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%attr(2755,root,privileged) %{_libexecdir}/harbour-mullvad-vpn
