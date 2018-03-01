import React from 'react';
import Toggle from 'material-ui/Toggle';

import { green800, green900, cyan500 } from 'material-ui/styles/colors';

import { getLink } from '../helpers';
import { SocialMediaList } from './social_media_list';

function getLogo(logo, logoURL) {
    if (!logo) {
      return;
    }
    return (<img role="presentation" src={logoURL} />);
  }

const styles = {
    toggle: {
      marginBottom: 5,
      width: 'auto',
      height: 'auto',
      float: 'left',
    },
    input: {
      width: '43%',
    },
    divToggle: {
      position: 'relative',
    },
    label: {
      width: 'calc(100% - 256)',
    }
  };

 export const RightBar = (props) => (
  <div className="right-menu-bar" >
     <div>
       {getLink(getLogo(props.config.logo, `${props.config.url}/${props.config.logo}`),
         '',
         props.config.url,
         '/')}
       </div>
      <div>
         <SocialMediaList social={props.config.social} />
       </div>
     </div>
);
