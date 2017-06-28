# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5
inherit savedconfig

# Tell linux-info where to find the kernel source/build
KERNEL_DIR="${SYSROOT}/usr/src/linux"
KBUILD_OUTPUT="${SYSROOT}/var/cache/portage/sys-kernel/coreos-kernel"
inherit linux-info

if [[ ${PV} == 99999999* ]]; then
	inherit git-2
	SRC_URI=""
	EGIT_REPO_URI="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
	KEYWORDS=""
else
	GIT_COMMIT="91ddce492dc0a6a718396e0c79101087134f622d"
	SRC_URI="https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-${GIT_COMMIT}.tar.xz -> ${P}.tar.xz"
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
fi

DESCRIPTION="Linux firmware files"
HOMEPAGE="https://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git"

LICENSE="GPL-1 GPL-2 GPL-3 BSD freedist"
SLOT="0"
IUSE="savedconfig"

CDEPEND=">=sys-kernel/coreos-modules-4.6.3-r1:="
DEPEND="${CDEPEND}
	sys-kernel/coreos-sources"
RDEPEND="${CDEPEND}
	!savedconfig? (
		!sys-firmware/alsa-firmware[alsa_cards_ca0132]
		!sys-firmware/alsa-firmware[alsa_cards_korg1212]
		!sys-firmware/alsa-firmware[alsa_cards_maestro3]
		!sys-firmware/alsa-firmware[alsa_cards_sb16]
		!sys-firmware/alsa-firmware[alsa_cards_ymfpci]
		!media-tv/cx18-firmware
		!<sys-firmware/ivtv-firmware-20080701-r1
		!media-tv/linuxtv-dvb-firmware[dvb_cards_cx231xx]
		!media-tv/linuxtv-dvb-firmware[dvb_cards_cx23885]
		!media-tv/linuxtv-dvb-firmware[dvb_cards_usb-dib0700]
		!net-dialup/ueagle-atm
		!net-dialup/ueagle4-atm
		!net-wireless/ar9271-firmware
		!net-wireless/i2400m-fw
		!net-wireless/libertas-firmware
		!sys-firmware/rt61-firmware
		!net-wireless/rt73-firmware
		!net-wireless/rt2860-firmware
		!net-wireless/rt2870-firmware
		!sys-block/qla-fc-firmware
		!sys-firmware/amd-ucode
		!sys-firmware/iwl1000-ucode
		!sys-firmware/iwl2000-ucode
		!sys-firmware/iwl2030-ucode
		!sys-firmware/iwl3945-ucode
		!sys-firmware/iwl4965-ucode
		!sys-firmware/iwl5000-ucode
		!sys-firmware/iwl5150-ucode
		!sys-firmware/iwl6000-ucode
		!sys-firmware/iwl6005-ucode
		!sys-firmware/iwl6030-ucode
		!sys-firmware/iwl6050-ucode
		!sys-firmware/iwl3160-ucode
		!sys-firmware/iwl7260-ucode
		!sys-firmware/iwl7265-ucode
		!sys-firmware/iwl3160-7260-bt-ucode
		!sys-firmware/radeon-ucode
	)"
#add anything else that collides to this


# source name is linux-firmware, not coreos-firmware
S="${WORKDIR}/linux-firmware-${PV}"

src_unpack() {
	if [[ ${PV} == 99999999* ]]; then
		git-2_src_unpack
	else
		default
		# rename directory from git snapshot tarball
		mv ${PN}-*/ ${P} || die
	fi
}

src_prepare() {
	local kernel_mods="${ROOT}/lib/modules/${KV_FULL}"

	# Fail if any firmware is missing.
	einfo "Scanning for files required by ${KV_FULL}"
	echo -n > "${T}/firmware-scan"
	local kofile fwfile failed
	for kofile in $(find "${kernel_mods}" -name '*.ko'); do
		for fwfile in $(modinfo --field firmware "${kofile}"); do
			if [[ ! -e "${fwfile}" ]]; then
				eerror "Missing firmware: ${fwfile} (${kofile##*/})"
				failed=1
			elif [[ -L "${fwfile}" ]]; then
				echo "${fwfile}" >> "${T}/firmware-scan"
				realpath --relative-to=. "${fwfile}" >> "${T}/firmware-scan"
			else
				echo "${fwfile}" >> "${T}/firmware-scan"
			fi
		done
	done
	if [[ -n "${failed}" ]]; then
		die "Missing firmware"
	fi

	if use savedconfig; then
		restore_config ${PN}.conf
		ebegin "Removing all files not listed in config"
		find * \( \! -type d -and \! -name ${PN}.conf \) \
			| sort ${PN}.conf ${PN}.conf - \
			| uniq -u | xargs -r rm
		eend $? || die
		# remove empty directories, bug #396073
		find -type d -empty -delete || die
	fi
}

src_install() {
	if use !savedconfig; then
		save_config ${PN}.conf
	fi
	rm ${PN}.conf || die
	insinto /lib/firmware/
	doins -r *
}

pkg_preinst() {
	if use savedconfig; then
		ewarn "USE=savedconfig is active. You must handle file collisions manually."
	fi
}

pkg_postinst() {
	elog "If you are only interested in particular firmware files, edit the saved"
	elog "configfile and remove those that you do not want."
}
